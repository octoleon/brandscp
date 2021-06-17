# == Schema Information
#
# Table name: attached_assets
#
#  id                    :integer          not null, primary key
#  file_file_name        :string(255)
#  file_content_type     :string(255)
#  file_file_size        :integer
#  file_updated_at       :datetime
#  asset_type            :string(255)
#  attachable_id         :integer
#  attachable_type       :string(255)
#  created_by_id         :integer
#  updated_by_id         :integer
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  active                :boolean          default("true")
#  direct_upload_url     :string(255)
#  rating                :integer          default("0")
#  folder_id             :integer
#  status                :integer          default("0")
#  processing_percentage :integer          default("0")
#

class AttachedAsset < ActiveRecord::Base
  # Defines the method do_search
  include SolrSearchable
  include EventBaseSolrSearchable

  track_who_does_it
  has_and_belongs_to_many :tags, -> { order 'name ASC' },
                          autosave: true,
                          after_add: ->(asset, _) { asset.index },
                          after_remove:  ->(asset, _) { asset.index }
  DIRECT_UPLOAD_URL_FORMAT = %r{\Ahttps:\/\/s3\.amazonaws\.com\/#{ENV['S3_BUCKET_NAME']}\/(?<path>uploads\/.+\/(?<filename>.+))\z}.freeze
  belongs_to :attachable, polymorphic: true
  belongs_to :folder, class_name: 'DocumentFolder'

  attr_accessor :new_name

  enum status: { queued: 0, processing: 1, processed: 2,  failed: 3 }

  has_attached_file :file,
                    PAPERCLIP_SETTINGS.merge(
                      styles: ->(a) do
                        if a.instance.pdf?
                          a.options[:convert_options] = {
                            thumbnail: '-quality 85 -strip -gravity north -thumbnail 300x400^ -extent 300x400'
                          }
                          { thumbnail: ['300x400>', :jpg] }
                        elsif a.instance.video?
                          # libx264 Video Codec for better browser support and quality
                          # 44100 Audio Sample Rate to avoid issues with Quicktime (mov) files
                          {
                            :small => { :geometry => '180x120#', :format => 'jpg' },
                            :thumbnail => { :geometry => '400x267#', :format => 'jpg' },
                            :medium => { :format => 'jpg' },
                            :video => { :format => 'mp4', :convert_options => { :output => { :vcodec => 'libx264', :ar => '44100' } } }
                          }
                        else
                          a.options[:convert_options] = {
                            small: '-quality 85 -strip -gravity north -thumbnail 180x180^ -extent 180x120',
                            thumbnail: '-quality 85 -strip -gravity north -thumbnail 400x400^ -extent 400x267',
                            medium: '-quality 85 -strip'
                          }
                          { small: '', thumbnail: '', medium: '800x800>' }
                        end
                      end,
                      processors: ->(instance) {
                        if instance.pdf?
                          [:ghostscript, :thumbnail]
                        elsif instance.video?
                          [:transcoder]
                        else
                          [:thumbnail]
                        end
                      }
                    )

  do_not_validate_attachment_file_type :file

  scope :for_events, ->(events) { where(attachable_type: 'Event', attachable_id: events) }
  scope :photos, -> { where(asset_type: 'photo') }
  scope :receipts, -> { where(asset_type: 'receipts') }
  scope :active, -> { where(active: true) }

  validate :valid_file_format?

  before_validation :set_upload_attributes

  after_commit :queue_processing, on: [:create]
  after_save :update_active_photos_count, if: -> { attachable.is_a?(Event) && self.photo? }
  after_destroy :update_active_photos_count, if: -> { attachable.is_a?(Event) && self.photo? }
  after_destroy :delete_queued_process
  after_update :rename_existing_file, if: :processed?
  after_update :queue_processing, if: :direct_upload_url_changed?
  before_post_process :post_process_required?

  validates :attachable, presence: true

  validates :direct_upload_url, allow_nil: true, on: :create,
                                uniqueness: true,
                                format: { with: DIRECT_UPLOAD_URL_FORMAT }
  validates :direct_upload_url, presence: true, unless: :file_file_name

  validate :max_event_photos, on: :create, if: proc { |a| a.attachable.is_a?(Event) && a.photo? }

  delegate :company_id, :update_active_photos_count, to: :attachable

  searchable do
    string :status
    string :asset_type do
      asset_type || (form_field_result? ? attachable.form_field.type.demodulize.underscore : nil)
    end
    string :attachable_type
    string :file_file_name
    string :file_content_type do
      if file_content_type.present?
        file_content_type.split('/')[0]
      else
        nil
      end
    end
    integer :file_file_size
    boolean :processed do
      processed?
    end
    integer :activity_type_id, multiple: true do
      a_type_id = nil
      if attachable.present?
        if attachable_type == 'Event'
          a_type_id = attachable.activities.map(&:activity_type_id)
        elsif form_field_result?
          if attachable.resultable_type == 'Activity'
            a_type_id = attachable.resultable.activity_type_id
          end
          if attachable.resultable_type == 'Event'
            a_type_id = attachable.resultable.activities.map(&:activity_type_id)
          end
        elsif attachable_type == 'EventExpense'
          a_type_id = attachable.event.activities.map(&:activity_type_id)
        end
      end
      a_type_id
    end
  
    integer :event_id do
      e_id = nil
      if attachable_type == 'Event'
        e_id = attachable_id
      elsif form_field_result?
        if attachable.resultable_type == 'Activity'
          e_id = attachable.resultable.activitable_id
        elsif attachable.resultable_type == 'Event'
          e_id = attachable.resultable_id
        end
      else
        e_id = nil
      end
      e_id
    end

    boolean :active

    string :tag, multiple: true do
      tags.pluck(:id)
    end
    integer :rating
    time :created_at

    integer :location, multiple: true do
      l_id = nil
      if attachable.present?
        if attachable_type == 'Event'
          l_id = attachable.place.try(:location_ids)
        elsif form_field_result?
          if attachable.resultable_type == 'Activity'
            if attachable.resultable.activitable_type == 'Venue' || attachable.resultable.activitable_type == 'Event'
              l_id = attachable.resultable.activitable.place.try(:location_ids)
            end
          end
          if attachable.resultable_type == 'Event'
            l_id = attachable.resultable.place.try(:location_ids)
          end
        elsif attachable_type == 'EventExpense'
          l_id = attachable.event.place.try(:location_ids)
        end
      end
      l_id
    end

    integer :place_id do
      p_id = nil
      if attachable.present?
        if attachable_type == 'Event'
          p_id = attachable.place_id
        elsif form_field_result?
          if attachable.resultable_type == 'Activity'
            if attachable.resultable.activitable_type == 'Venue' || attachable.resultable.activitable_type == 'Event'
              p_id = attachable.resultable.activitable.place_id
            end
          end
          if attachable.resultable_type == 'Event'
            p_id = attachable.resultable.place_id
          end
        elsif attachable_type == 'EventExpense'
          p_id = attachable.event.place_id
        end
      end
      p_id
    end

    join(:company_id, target: Event, type: :integer, join: { from: :id, to: :event_id }, as: :company_id_i)
    #company_is is used by delegate
    integer :company_id do
      if attachable.present?
        attachable.company_id
      else
        nil
      end
    end

    join(:user_ids, target: Event, type: :integer, join: { from: :id, to: :event_id }, as: :user_ids_im)
    join(:team_ids, target: Event, type: :integer, join: { from: :id, to: :event_id }, as: :team_ids_im)
    join(:campaign_id, target: Event, type: :integer, join: { from: :id, to: :event_id }, as: :campaign_id_is)

    time :start_at do
      date = nil
      if attachable.present?
        if attachable_type == 'Event'
          date = attachable.start_at
        elsif form_field_result?
          if attachable.resultable_type == 'Activity'
            if attachable.resultable.activitable_type == 'Venue' || attachable.resultable.activitable_type == 'Event'
              date = attachable.resultable.activity_date
            end
          end
          if attachable.resultable_type == 'Event'
            date = attachable.resultable.start_at
          end
        elsif attachable_type == 'EventExpense'
          date = attachable.expense_date
        end
      end
      date
    end

    time :end_at do
      date = nil
      if attachable.present?
        if attachable_type == 'Event'
          date = attachable.end_at
        elsif form_field_result?
          if attachable.resultable_type == 'Activity'
            if attachable.resultable.activitable_type == 'Venue' || attachable.resultable.activitable_type == 'Event'
              date = attachable.resultable.activity_date
            end
          end
          if attachable.resultable_type == 'Event'
            date = attachable.resultable.end_at
          end
        elsif attachable_type == 'EventExpense'
          date = attachable.expense_date
        end
      end
      date
    end

    time :local_start_at do
      date = nil
      if attachable.present?
        if attachable_type == 'Event'
          date = attachable.local_start_at
        elsif form_field_result?
          if attachable.resultable_type == 'Activity'
            if attachable.resultable.activitable_type == 'Venue' || attachable.resultable.activitable_type == 'Event'
              date = attachable.resultable.activity_date
            end
          end
          if attachable.resultable_type == 'Event'
            date = attachable.resultable.local_start_at
          end
        elsif attachable_type == 'EventExpense'
          date = attachable.expense_date
        end
      end
      date
    end

    time :local_end_at do
      date = nil
      if attachable.present?
        if attachable_type == 'Event'
          date = attachable.local_end_at
        elsif form_field_result?
          if attachable.resultable_type == 'Activity'
            if attachable.resultable.activitable_type == 'Venue' || attachable.resultable.activitable_type == 'Event'
              date = attachable.resultable.activity_date
            end
          end
          if attachable.resultable_type == 'Event'
            date = attachable.resultable.local_end_at
          end
        elsif attachable_type == 'EventExpense'
          date = attachable.expense_date
        end
      end
      date
    end
  end

  def form_field_result?
    attachable_type == 'FormFieldResult' && attachable.present?
  end

  def searchable_params
    [start_date: [], end_date: [], status: [], campaign: [], location: [],
     venue: [],event: [], place: [], media_type:[], activity_type:[]]
  end
  def activate!
    update_attribute :active, true
  end

  def name
    file_file_name.gsub("\.#{file_extension}", '')
  end

  def deactivate!
    update_attribute :active, false
  end

  def status
    self.active? ? 'Active' : 'Inactive'
  end

  def file_extension
    File.extname(file_file_name)[1..-1] if file_file_name
  end

  # Store an unescaped version of the escaped URL that Amazon returns from direct upload.
  def direct_upload_url=(escaped_url)
    write_attribute(:direct_upload_url, (CGI.unescape(escaped_url) rescue nil))
  end

  def download_url(style_name = :original)
    file.s3_bucket.objects[file.s3_object(style_name).key]
      .url_for(
        :read, secure: true,
               force_path_style: true,
               expires: 24 * 3600, # 24 hours
               response_content_disposition: "attachment; filename=#{file_file_name}").to_s
  end

  def preview_url(style_name = :medium, opts = {})
    if pdf?
      file.url(:thumbnail, opts)
    else
      file.url(style_name, opts)
    end
  end

  def is_thumbnable?
    %r{^(image|(x-)?application|video)/(bmp|gif|jpeg|jpg|pjpeg|png|x-png|pdf|mp4|x-ms-wmv|quicktime|x-flv|x-msvideo)$}.match(file_content_type).present?
  end

  def image?
    %r{^(image|(x-)?application)/(bmp|gif|jpeg|jpg|pjpeg|png|x-png)$}.match(file_content_type).present?
  end

  def pdf?
    %r{^(x-)?application/pdf$}.match(file_content_type).present?
  end

  def video?
    %r{^(video)/(mp4|x-ms-wmv|quicktime|x-flv|x-msvideo)$}.match(file_content_type).present?
  end

  class << self
    def compress(ids)
      assets_ids = ids.sort.map(&:to_i)
      download = AssetDownload.find_or_create_by_assets_ids(assets_ids, assets_ids: assets_ids)
      download.queue! if download.new?
      download
    end
  end

  # Moving the original file to final path
  def move_uploaded_file
    direct_upload_url_data = DIRECT_UPLOAD_URL_FORMAT.match(direct_upload_url)

    paperclip_file_path = file.path(:original).sub(/\A\//, '')
    begin
      file.s3_bucket.objects[paperclip_file_path].copy_from(
        direct_upload_url_data[:path], acl: :public_read)
    rescue AWS::S3::Errors::NoSuchKey
    end
  end

  def self.copy_file_to_uploads_folder(url)
    path = CGI.unescape(URI.parse(URI.encode(url)).path.gsub("/#{ENV['S3_BUCKET_NAME']}/", ''))
    paperclip_file_path = "uploads/#{Time.now.to_i}-#{rand(5000)}/#{File.basename(path)}"
    AWS::S3.new.buckets[ENV['S3_BUCKET_NAME']].objects[paperclip_file_path].copy_from(
      path, acl: :public_read)
    "https://s3.amazonaws.com/#{ENV['S3_BUCKET_NAME']}/#{paperclip_file_path}"
  rescue AWS::S3::Errors::NoSuchKey
    nil
  end

  # Rename existing file in S3
  def rename_existing_file
    return unless file_file_name_changed?

    (file.styles.keys + [:original]).each do |style|
      dirname = File.dirname(file.path(style).sub(/\A\//, ''))
      old_path = "#{dirname}/#{file_file_name_was}"
      new_path = "#{dirname}/#{file_file_name}"
      begin
        file.s3_bucket.objects[old_path].move_to(new_path, acl: :public_read)
      rescue AWS::S3::Errors::NoSuchKey
      end
    end

    (file.styles.keys + [:medium]).each do |style|
      dirname = File.dirname(file.path(style).sub(/\A\//, ''))
      old_path = "#{dirname}/#{file_file_name_was}"
      new_path = "#{dirname}/#{file_file_name}"
      begin
        file.s3_bucket.objects[old_path].move_to(new_path, acl: :public_read)
      rescue AWS::S3::Errors::NoSuchKey
      end
    end


    (file.styles.keys + [:small]).each do |style|
      dirname = File.dirname(file.path(style).sub(/\A\//, ''))
      old_path = "#{dirname}/#{file_file_name_was}"
      new_path = "#{dirname}/#{file_file_name}"
      begin
        file.s3_bucket.objects[old_path].move_to(new_path, acl: :public_read)
      rescue AWS::S3::Errors::NoSuchKey
      end
    end

    (file.styles.keys + [:thumbnail]).each do |style|
      dirname = File.dirname(file.path(style).sub(/\A\//, ''))
      old_path = "#{dirname}/#{file_file_name_was}"
      new_path = "#{dirname}/#{file_file_name}"
      begin
        file.s3_bucket.objects[old_path].move_to(new_path, acl: :public_read)
      rescue AWS::S3::Errors::NoSuchKey
      end
    end
  end

  # Final upload processing step
  def transfer_and_cleanup
    processing!
    if post_process_required?
      file.reprocess!
    end
    self.processing_percentage = 100

    direct_upload_url_data = DIRECT_UPLOAD_URL_FORMAT.match(direct_upload_url)

    direct_upload_url = nil
    processed!
    file.s3_bucket.objects[direct_upload_url_data[:path]].delete if save

    delete_queued_process
  end

  def photo?
    asset_type == 'photo'
  end

  protected

  def valid_file_format?
    return unless asset_type.to_s == 'photo' || asset_type.to_s == 'video'
    if /\A(image|(x-)?application)\/(bmp|gif|jpeg|jpg|pjpeg|png|x-png)\z/.match(file_content_type).nil? &&
      /\A(video)\/(mp4|x-ms-wmv|quicktime|x-flv|x-msvideo)\z/.match(file_content_type).nil?
      errors.add(:file, "#{file_file_name} is not valid format")
    end
  end

  # Determines if file requires post-processing (image resizing, etc)
  def post_process_required?
    is_thumbnable?
  end

  # Set attachment attributes from the direct upload
  # @note Retry logic handles S3 "eventual consistency" lag.
  def set_upload_attributes
    tries ||= 3
    direct_url_changed = direct_upload_url.present? && self.direct_upload_url_changed?
    if ((new_record? && file_file_name.nil?) || direct_url_changed) && direct_upload_url_data = DIRECT_UPLOAD_URL_FORMAT.match(direct_upload_url)
      direct_upload_head = file.s3_bucket.objects[direct_upload_url_data[:path]].head

      self.file_file_name     = file.send(:cleanup_filename, direct_upload_url_data[:filename])
      self.file_file_size     = direct_upload_head.content_length
      self.file_content_type  = direct_upload_head.content_type
      self.file_updated_at    = direct_upload_head.last_modified

      if file_content_type == 'binary/octet-stream'
        self.file_content_type = MIME::Types.type_for(file_file_name).first.to_s
      end
    end
  rescue Errno::ECONNRESET, Net::ReadTimeout, Net::ReadTimeout => e
    tries -= 1
    if tries > 0
      sleep(1)
      retry
    else
      self.fail!
      raise e
    end
  rescue AWS::S3::Errors::NoSuchKey
  end

  # Queue file processing
  def queue_processing
    return if !queued? && direct_upload_url.nil?
    move_uploaded_file
    if post_process_required?
      AssetsUploadWorker.perform_async(id, self.class.name)
    else
      transfer_and_cleanup
    end
    true
  end

  # Delete associated queued process
  def delete_queued_process
    return unless queued?

    queue = Sidekiq::Queue.new('upload')
    queue.each do |job|
      next unless job.args.include? id
      job.delete
      break
    end
  end

  def max_event_photos
    return true unless attachable.campaign.range_module_settings?('photos')
    max = attachable.campaign.module_setting('photos', 'range_max')
    return true if max.blank? || attachable.photos.active.count < max.to_i
    errors.add(:base, I18n.translate('instructive_messages.execute.photo.add_exceeded', count: max.to_i))
  end
end
