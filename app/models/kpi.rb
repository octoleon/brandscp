# encoding: utf-8
# == Schema Information
#
# Table name: kpis
#
#  id                :integer          not null, primary key
#  name              :string(255)
#  description       :text
#  kpi_type          :string(255)
#  capture_mechanism :string(255)
#  company_id        :integer
#  created_by_id     :integer
#  updated_by_id     :integer
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  module            :string(255)      default("custom"), not null
#  ordering          :integer
#

class Kpi < ActiveRecord::Base
  track_who_does_it

  has_paper_trail

  scoped_to_company

  CUSTOM_TYPE_OPTIONS = { 'number'     => %w(integer decimal currency),
                          'count'      => %w(radio dropdown checkbox),
                          'percentage' => %w(integer decimal) }

  OUT_BOX_TYPE_OPTIONS = %w(promo_hours events_count photos videos surveys expenses comments)

  GOAL_ONLY_TYPE_OPTIONS = OUT_BOX_TYPE_OPTIONS + ['number']

  COMPLETE_TYPE_OPTIONS = CUSTOM_TYPE_OPTIONS.keys + OUT_BOX_TYPE_OPTIONS

  SEGMENTS_COUNT_MIN = { 'radio'     => 2,
                         'dropdown'  => 1,
                         'checkbox'  => 1 }

  validates :name, presence: true, uniqueness: { scope: :company_id }
  validates :company_id, numericality: true, allow_nil: true
  validates :kpi_type, inclusion: { in: COMPLETE_TYPE_OPTIONS, message: '%{value} is not valid' }

  validates_associated :kpis_segments

  validate :segments_can_be_deleted?

  validate :segments_count_valid?

  # KPIs-Segments relationship
  has_many :kpis_segments, -> { order 'ordering ASC, id ASC' }, inverse_of: :kpi, dependent: :destroy

  has_many :form_fields

  # KPIs-Goals relationship
  has_many :goals, inverse_of: :kpi, dependent: :destroy

  accepts_nested_attributes_for :kpis_segments, reject_if: lambda { |x| x[:text].blank? && x[:id].blank? }, allow_destroy: true
  accepts_nested_attributes_for :goals, reject_if: :invalid_goal?

  scope :global, lambda { where('company_id is null').order('ordering ASC') }
  scope :custom, lambda { |company| where(company_id: company).order('name ASC') }
  scope :global_and_custom, lambda { |company| where('company_id is null or company_id=?', company).order('company_id DESC, id ASC') }
  scope :in_module, lambda { where('module is not null and module != \'\'') }
  scope :not_segmented, lambda { where(['kpi_type not in (?) ', %w(percentage count)]) }
  scope :campaign_assignable, ->(campaign) {
    global_and_custom(campaign.company)
    .where('id not in (?)', campaign.kpi_ids + [Kpi.events, Kpi.promo_hours].compact + [0])
    .reorder('name ASC')
  }
  scope :form_assignable, -> {
    where('id not in (?)', [Kpi.events, Kpi.promo_hours].compact + [0])
    .where('module in (?)', %w(custom demographics consumer_reach))
    .reorder('name ASC')
  }

  scope :campaign_eq, ->() { self }

  after_save :sync_segments_and_goals

  def self.campaign_eq(campaigns)
    joins(:form_fields)
      .where(form_fields: {
               fieldable_type: 'Campaign',
               fieldable_id: campaigns })
  end

  def self.ransackable_scopes(_auth_object = nil)
    [:campaign_eq]
  end

  searchable do
    text :name, stored: true
    string :name
    integer :company_id
  end

  def out_of_the_box?
    self.module != 'custom'
  end

  def is_segmented?
    ['percentage'].include? kpi_type
  end

  def currency?
    capture_mechanism == 'currency'
  end

  def self.ransackable_scopes(_auth_object = nil)
    [:campaign_eq]
  end

  def sync_segments_and_goals
    unless self.out_of_the_box?
      if GOAL_ONLY_TYPE_OPTIONS.include?(kpi_type)
        kpis_segments.destroy_all
      else
        goals.where(kpis_segment_id: nil).delete_all
      end
    end
  end

  def form_field_type
    case kpi_type
    when 'text', 'textarea'
      'FormField::Text'
    when 'number'
      if capture_mechanism == 'currency'
        'FormField::Currency'
      else
        'FormField::Number'
      end
    when 'count'
      case capture_mechanism
      when 'radio' then 'FormField::Radio'
      when 'checkbox' then 'FormField::Checkbox'
      else 'FormField::Dropdown'
      end
    when 'percentage'
      'FormField::Percentage'
    when 'section'
      'FormField::Section'
    end
  end

  def form_field_options
    {
      name: name,
      type: form_field_type,
      kpi_id: id,
      options: (%w(count percentage).include?(kpi_type) ? segments.each_with_index.map { |s, i| { id: s[0], name: s[1], ordering: i } } : [])
    }
  end

  def segments_names
    segments.map { |s| s[1] }
  end

  def segments
    @segments ||= kpis_segments.pluck(:id, :text)
  end

  class << self
    def events
      global.find_by(name: 'Events', kpi_type: 'events_count')
    end

    def promo_hours
      global.find_by(name: 'Promo Hours', kpi_type: 'promo_hours')
    end

    def impressions
      global.find_by(name: 'Impressions', module: 'consumer_reach')
    end

    def interactions
      global.find_by(name: 'Interactions', module: 'consumer_reach')
    end

    def samples
      global.find_by(name: 'Samples', module: 'consumer_reach')
    end

    def expenses
      global.find_by(name: 'Expenses', module: 'expenses')
    end

    def gender
      global.find_by(name: 'Gender', module: 'demographics')
    end

    def age
      global.find_by(name: 'Age', module: 'demographics')
    end

    def ethnicity
      global.find_by(name: 'Ethnicity/Race', module: 'demographics')
    end

    def photos
      global.find_by(name: 'Photos', module: 'photos')
    end

    def videos
      global.find_by(name: 'Videos', module: 'videos')
    end

    def surveys
      global.find_by(name: 'Surveys', module: 'surveys')
    end

    def comments
      global.find_by(name: 'Comments', module: 'comments')
    end

    # This method is only used during the DB seed and tests
    def create_global_kpis
      Kpi.global.destroy_all
      without_company_scoped do
        Kpi.create(name: 'Events', kpi_type: 'events_count', description: 'Number of events executed', capture_mechanism: '', company_id: nil, 'module' => '', ordering: 1)
        Kpi.create(name: 'Promo Hours', kpi_type: 'promo_hours', description: 'Total duration of events', capture_mechanism: '', company_id: nil, 'module' => '', ordering: 2)
        Kpi.create(name: 'Impressions', kpi_type: 'number', description: 'Total number of consumers who come in contact with an event', capture_mechanism: 'integer', company_id: nil, 'module' => 'consumer_reach', ordering: 3)
        Kpi.create(name: 'Interactions', kpi_type: 'number', description: 'Total number of consumers who directly interact with an event', capture_mechanism: 'integer', company_id: nil, 'module' => 'consumer_reach', ordering: 4)
        Kpi.create(name: 'Samples', kpi_type: 'number', description: 'Number of consumers who try a product sample', capture_mechanism: 'integer', company_id: nil, 'module' => 'consumer_reach', ordering: 5)
        Kpi.create(name: 'Gender', kpi_type: 'percentage', description: 'Number of consumers who try a product sample', capture_mechanism: 'integer', company_id: nil, 'module' => 'demographics', ordering: 6)
        Kpi.create(name: 'Age', kpi_type: 'percentage', description: 'Percentage of attendees who are within a certain age range', capture_mechanism: 'integer', company_id: nil, 'module' => 'demographics', ordering: 7)
        Kpi.create(name: 'Ethnicity/Race', kpi_type: 'percentage', description: 'Percentage of attendees who are of a certain ethnicity or race', capture_mechanism: 'integer', company_id: nil, 'module' => 'demographics', ordering: 8)
        Kpi.create(name: 'Photos', kpi_type: 'photos', description: 'Total number of photos uploaded to an event', capture_mechanism: '', company_id: nil, 'module' => 'photos', ordering: 9)
        Kpi.create(name: 'Expenses', kpi_type: 'expenses', description: 'Total expenses of an event', capture_mechanism: 'currency', company_id: nil, 'module' => 'expenses', ordering: 10)
        Kpi.create(name: 'Videos', kpi_type: 'videos', description: 'Total number of photos uploaded to an event', capture_mechanism: '', company_id: nil, 'module' => 'videos', ordering: 11)
        Kpi.create(name: 'Surveys', kpi_type: 'surveys', description: 'Total number of surveys completed for a campaign', capture_mechanism: 'integer', company_id: nil, 'module' => 'surveys', ordering: 12)
        Kpi.create(name: 'Comments', kpi_type: 'comments', description: 'Total number of comments from event audience', capture_mechanism: 'integer', company_id: nil, 'module' => 'comments', ordering: 13)
        Kpi.create(name: 'Competitive Analysis', kpi_type: 'number', description: 'Total number of competitive analyses created for a campaign', capture_mechanism: 'integer', company_id: nil, 'module' => 'competitive_analysis', ordering: 14)
      end

      ['< 12', '12 - 17', '18 - 24', '25 - 34', '35 - 44', '45 - 54', '55 - 64', '65+'].each do |segment|
        age.kpis_segments.create(text: segment)
      end

      %w(Female Male).each do |segment|
        gender.kpis_segments.create(text: segment)
      end

      ['Asian', 'Black / African American', 'Hispanic / Latino', 'Native American', 'White'].each do |segment|
        ethnicity.kpis_segments.create(text: segment)
      end
    end

    def merge_fields(options)
      kpis = all

      # Only to prevent a terrible mistake :p, do not allow
      # this being called for more than one out-of-the-box KPIs
      return false if kpis.select(&:out_of_the_box?).count > 1

      campaings = FormField.includes(:fieldable).where(kpi_id: kpis, fieldable_type: 'Campaign').map(&:fieldable)
      Kpi.transaction do

        # STEP 1: merge the values of events if the campaign has more than one of the chosen KPIs
        # to merge
        # Campaing A has KPI: "# impressions"
        # Campaing A has KPI: "# of impressions"
        campaings.each do |campaign|
          kpi_keep = kpis.find { |k| k.id == options['master_kpi'][campaign.id.to_s].to_i }
          kpis_to_remove = campaign.active_kpis.select { |k| kpis.include?(k) && k.id != kpi_keep.id }

          if kpi_keep
            # If this campaing has at leas more than one
            if kpis_to_remove.count > 0
              campaign.events.find_in_batches do |group|
                group.each do |event|
                  event.campaign = campaign # To avoid each event to reload the campaign
                  if kpi_keep.kpi_type == 'percentage'
                    results = event.result_for_kpi(kpi_keep)
                    if results.value.values.map(&:to_i).sum == 0
                      values_to_copy = kpis_to_remove.each do|k|
                        values_to_copy = event.result_for_kpi(k)
                        if values_to_copy.map(&:value).map(&:to_i) != 0
                          values_to_copy.each do |result_copy|
                            if result = results.find { |r| r.kpis_segment.text.downcase.strip == result_copy.kpis_segment.text.downcase.strip }
                              result.value = result_copy.value
                              result.save
                            end
                          end
                        end
                      end
                    end
                  else
                    result = event.result_for_kpi(kpi_keep)
                    value = result.value
                    # If the event doesn't have a value for that field, then try looking for a value on another KPI
                    if value.nil? || value == ''
                      value ||= kpis_to_remove.map { |k| r = event.result_for_kpi(k); r.value }.compact.first
                      if kpi_keep.kpi_type == 'count'
                        option_text = KpisSegment.find(value).text.downcase.strip rescue nil
                        value = kpi_keep.kpis_segments.find { |s| s.text.downcase.strip == option_text }.try(:id) if option_text
                      end
                      result.value = value
                      result.save
                    end
                  end
                end
              end
              FormFieldResult.where("id in (#{FormFieldResult.select('form_field_results.id').for_kpi(kpis_to_remove).for_event_campaign(campaign).to_sql})").delete_all
              FormField.where(fieldable_type: 'Campaign', fieldable_id: campaign.id, kpi_id: kpis_to_remove).destroy_all
            else

            end
            # CampaignFormField.where(kpi_id: kpis_to_remove).destroy_all
            # EventResult.where(kpi_id: kpis_to_remove).destroy_all
            # kpis_to_remove.each{|k| k.destroy unless k.out_of_the_box? }
          end
        end
      end

      # STEP 2: merge any remaining KPIs that are in more than one campaign, example:
      # Campaing A has KPI: "# impressions"
      # Campaing B has KPI: "# of impressions"
      remaining_kpis = all.to_a
      kpi_keep = nil
      if remaining_kpis.count > 0
        kpi_keep = remaining_kpis.find(proc { remaining_kpis.first }) { |k| k.out_of_the_box? }
        remaining_kpis.reject! { |k| k == kpi_keep }
        FormField.where(kpi_id: remaining_kpis).each do |field|
          if field.kpi.kpi_type == 'percentage'
            field.kpi.kpis_segments.each do |segment|
              if new_segment = kpi_keep.kpis_segments.find { |s| s.text.downcase.strip == segment.text.downcase.strip }
                # EventResult.where(kpi_id: field.kpi.id, kpis_segment_id: segment.id).update_all(kpi_id: kpi_keep.id, kpis_segment_id: new_segment.id)
                FormFieldResult.for_kpi(field.kpi).update_all("hash_value = delete(hash_value || hstore(ARRAY['#{new_segment.id}', hash_value->'#{segment.id}']), '#{segment.id}')")
              end
            end
          elsif field.kpi.kpi_type == 'count'
            field.kpi.kpis_segments.each do |segment|
              if new_segment = kpi_keep.kpis_segments.find { |s| s.text.downcase.strip == segment.text.downcase.strip }
                FormFieldResult.for_kpi(field.kpi).where(value: segment.id.to_s).update_all(value: new_segment.id)
              end
            end
            # else
            #   FormFieldResult.for_kpi(remaining_kpis).for_event_campaign(field.fieldable).update_all(kpi_id: kpi_keep)
          end
        end
        FormField.where(kpi_id: remaining_kpis).update_all(kpi_id: kpi_keep)
        remaining_kpis.each { |k| k.destroy unless k.out_of_the_box? }
      else
        kpi_keep = remaining_kpis.first
      end

      if kpi_keep
        unless kpi_keep.out_of_the_box?
          kpi_keep.name = options['name']
          kpi_keep.description = options['description']
          kpi_keep.save
        end
        FormField.where(kpi_id: kpi_keep).update_all(name: options['name'])
      end
    end
  end

  def segments_can_be_deleted?
    kpis_segments.select(&:marked_for_destruction?).each do |segment|
      errors.add :base, 'Cannot delete segments with results' if segment.has_results?
    end
  end

  def invalid_goal?(goal)
    goal['kpis_segment_id'].nil? && %w(count percentage).include?(kpi_type)
  end

  def segments_count_valid?
    # Valid if no restrictions for the selected capture mechanism or if segments count is less
    # than the quantity permitted for the selected capture mechanism
    min_count = SEGMENTS_COUNT_MIN[capture_mechanism] if SEGMENTS_COUNT_MIN.key?(capture_mechanism)
    if min_count && kpis_segments.reject(&:marked_for_destruction?).count < min_count
      errors.add :kpi_type, "You need to add at least #{min_count} segments for the selected capture mechanism"
    end
  end
end
