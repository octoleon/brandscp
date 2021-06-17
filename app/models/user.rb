# == Schema Information
#
# Table name: users
#
#  id                        :integer          not null, primary key
#  first_name                :string(255)
#  last_name                 :string(255)
#  email                     :string(255)      default(""), not null
#  encrypted_password        :string(255)      default("")
#  reset_password_token      :string(255)
#  reset_password_sent_at    :datetime
#  remember_created_at       :datetime
#  sign_in_count             :integer          default("0")
#  current_sign_in_at        :datetime
#  last_sign_in_at           :datetime
#  current_sign_in_ip        :string(255)
#  last_sign_in_ip           :string(255)
#  confirmation_token        :string(255)
#  confirmed_at              :datetime
#  confirmation_sent_at      :datetime
#  unconfirmed_email         :string(255)
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  country                   :string(4)
#  state                     :string(255)
#  city                      :string(255)
#  created_by_id             :integer
#  updated_by_id             :integer
#  invitation_token          :string(255)
#  invitation_sent_at        :datetime
#  invitation_accepted_at    :datetime
#  invitation_limit          :integer
#  invited_by_id             :integer
#  invited_by_type           :string(255)
#  current_company_id        :integer
#  time_zone                 :string(255)
#  detected_time_zone        :string(255)
#  phone_number              :string(255)
#  street_address            :string(255)
#  unit_number               :string(255)
#  zip_code                  :string(255)
#  authentication_token      :string(255)
#  invitation_created_at     :datetime
#  avatar_file_name          :string(255)
#  avatar_content_type       :string(255)
#  avatar_file_size          :integer
#  avatar_updated_at         :datetime
#  phone_number_verified     :boolean
#  phone_number_verification :string(255)
#

class User < ActiveRecord::Base
  track_who_does_it

  acts_as_reader

  has_paper_trail

  include SentientUser

  # Include default devise modules. Others available are:
  # :confirmable,
  # :lockable, :timeoutable and :omniauthable, :confirmable,
  devise :invitable, :database_authenticatable,
         :recoverable, :rememberable, :trackable, :confirmable

  has_many :company_users, dependent: :destroy
  has_many :custom_activity_forms_result_headers

  has_many :companies, -> { order 'companies.name ASC' }, through: :company_users
  belongs_to :current_company, class_name: 'Company'

  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :email, presence: true
  validates :detected_time_zone, allow_nil: true, inclusion: { in: ActiveSupport::TimeZone.all.map { |m| m.name.to_s } }

  validate :valid_verification_code?, if: :verification_code

  has_attached_file :avatar, styles: { small: '100x100#', large: '500x500>' }, processors: [:cropper]

  with_options unless: [:inviting_user_or_invited?, :reset_password_requested?] do |user|
    user.validates :phone_number, presence: true
    user.validates :country, presence: true
    user.validates :state, presence: true
    user.validates :city, presence: true
    user.validates :street_address, presence: true
    user.validates :zip_code, presence: true
    user.validates :time_zone, presence: true, inclusion: { in: ActiveSupport::TimeZone.all.map { |m| m.name.to_s } }
    user.validates :password, presence: true, if: :should_require_password?
    user.validates :password, confirmation: true, if: :password
  end

  # validates_associated :company_users

  validates_uniqueness_of :email, allow_blank: true, if: :email_changed?
  validates_format_of :email, with: /\A[^@\s]+@([^@\s]+\.)+[^@\s]+\z/, allow_blank: true, if: :email_changed?

  validates_length_of :password, within: 8..128, allow_blank: true
  validates_format_of :password, with: /[A-Z]/, allow_blank: true, message: 'should have at least one upper case letter'
  validates_format_of :password, with: /[0-9]/, allow_blank: true, message: 'should have at least one digit'
  validates_confirmation_of :password

  accepts_nested_attributes_for :company_users, allow_destroy: false

  delegate :name, :id, :permissions, to: :role, prefix: true, allow_nil: true

  scope :active_eq, -> { where('invitation_accepted_at is not null') }
  scope :active, -> { where('invitation_accepted_at is not null') }
  scope :active_in_company, ->(company) { active.joins(:company_users).where(company_users: { company_id: company, active: true }) }
  scope :in_company, ->(company) { active_in_company(company) }
  scope :accessible_by_user, ->(user) { in_company(user.company_id) }

  # search_methods :active_eq if ENV['WEB']
  if ENV['WEB']
    ransacker :active do
      Arel.sql("#{table_name}.invitation_accepted_at is not null")
    end
  end

  # Tasks-Users relationship
  has_many :tasks, through: :company_users

  has_many :events, through: :company_users

  before_save :ensure_authentication_token
  after_commit :reindex_related, on: :create, if: :persisted?
  before_validation :reset_verification
  after_invitation_accepted :reindex_company_users
  after_update :reprocess_avatar, if: :cropping?

  attr_accessor :verification_code
  attr_accessor :crop_x, :crop_y, :crop_w, :crop_h
  attr_accessor :inviting_user
  attr_accessor :updating_user
  attr_accessor :accepting_invitation
  attr_accessor :invitation_created_at
  attr_accessor :invitation_updated_at

  def full_name
    "#{first_name} #{last_name}".strip
  end


  alias_method :name, :full_name


  def is_fully_valid?
    if !phone_number.present? ||
       !country.present? ||
       !state.present? ||
       !city.present? ||
       !street_address.present? ||
       !zip_code.present?
      return false
    else
      return true
    end
  end

  # Returns the formatted user's adddress.
  # TODO: move this to a decorator/presenter
  def full_address(separator: '<br />')
    address = []
    city_parts = []
    city_parts.push city if city.present?
    city_parts.push state if state.present?
    address.push street_address if street_address.present?
    address.push unit_number if unit_number.present?
    address.push city_parts.compact.join(', ') unless city_parts.empty?
    address.push zip_code if zip_code.present?
    address.push country_name if country_name.present?
    address.compact.compact.join(separator).html_safe
  end

  def country_name
    load_country.name rescue nil unless load_country.nil?
  end

  def state_name
    load_country.states[state]['name'] rescue nil if load_country && state
  end

  def simple_address
    simple_address = []
    simple_address.push state if state
    simple_address.push country_name if country
    simple_address.join(' ,')
  end
  def load_country
    @the_country ||= Country.new(country) if country
  end

  def cropping?
    !crop_x.blank? && !crop_y.blank? && !crop_w.blank? && !crop_h.blank?
  end

  def generate_and_send_phone_verification_code
    update_column :phone_number_verification, sprintf('%06d', rand(5**10))[0..5]
    SendSmsWorker.perform_async(phone_number, "Your App verification code is #{phone_number_verification}")
  end

  # Method for Devise to make that only active users can login into the app
  def active_for_authentication?
    super && !invited_to_sign_up? && company_users.any? { |cu| cu.active? && cu.role.active? }
  end

  def inactive_message
    if company_users.any? { |cu| cu.role.active? }
      super
    elsif company_users.any?(&:active?)
      :invalid
    else
      super
    end
  end

  def role
    @role ||= current_company_user.try(:role)
  end

  def companies_active_role
    Company.order(:name).where(
      id: company_users.joins(:role).where(active: true, roles: { active: true }).pluck(:company_id))
  end

  def is_super_admin?
    role.is_admin? unless role.nil?
  end

  def current_company_user
    @current_company_user ||= begin
      if current_company_id.present?
        if company_users.loaded?
          company_users.select { |cu| cu.company_id == current_company_id }.first
        else
          company_users.where(company_id: current_company_id).first
        end
      end
    end
  end

  def inviting_user_or_invited?
    inviting_user || (invited_to_sign_up? && !accepting_invitation) || updating_user
  end

  def reset_password_requested?
    !(reset_password_token.nil? && reset_password_sent_at.nil?)
  end

  def should_require_password?
    accepting_invitation
  end

  def reindex_related
    Sunspot.index tasks if first_name_changed? || last_name_changed?
  end

  def reindex_company_users
    Sunspot.index company_users.all
  end

  # Update password saving the record and clearing token. Returns true if
  # the passwords are valid and the record was saved, false otherwise.
  def reset_password!(new_password, new_password_confirmation)
    self.password = new_password
    self.password_confirmation = new_password_confirmation

    clear_reset_password_token
    after_password_reset

    save(validate: false)
  end

  # Make this public
  def invitation_period_valid?
    super
  end

  class << self
    def report_fields
      {
        full_name:      { title: 'Full Name', column: -> { "first_name || ' ' || last_name" }, filter_column: -> { "first_name || ' ' || last_name" } },
        first_name:     { title: 'First Name' },
        last_name:      { title: 'Last Name' },
        email:          { title: 'Email' },
        country:        { title: 'Country' },
        state:          { title: 'State' },
        city:           { title: 'City' },
        street1:        { title: 'Street 1' },
        street2:        { title: 'Street 2' }
      }
    end

    # Find a user by its confirmation token and try to confirm it.
    # If no user is found, returns a new user with an error.
    # If the user is already confirmed, create an error for the user
    # Options must have the confirmation_token
    def confirm_by_token(confirmation_token)
      confirmable = find_first_by_auth_conditions(confirmation_token: confirmation_token)
      unless confirmable
        confirmation_digest = Devise.token_generator.digest(self, :confirmation_token, confirmation_token)
        confirmable = find_or_initialize_with_error_by(:confirmation_token, confirmation_digest)
      end
      confirmable.inviting_user = true
      confirmable.confirmation_token = nil
      confirmable.confirm if confirmable.persisted?
      confirmable
    end

    # Attempt to find a user by its email. If a record is found, send new
    # password instructions to it. If user is not found, returns a new user
    # with an email not found error.
    # Attributes must contain the user's email
    def send_reset_password_instructions(attributes = {})
      recoverable = User.joins(company_users: :role).where(company_users: { active: true }, roles: { active: true }).where(['lower(users.email) = ?', attributes[:email].downcase]).first
      if recoverable.nil?
        recoverable = User.new(attributes.permit(:email))
        recoverable.errors.add(:base, :reset_email_not_found)
      else
        recoverable = User.find(recoverable.id)
        recoverable.send_reset_password_instructions if recoverable.persisted?
      end
      recoverable
    end

    # This method is overrided to remove the call to the deprected method Devise.allow_insecure_token_lookup
    # TODO: check if this was corrected on gem and remove this from this file
    def find_by_invitation_token(original_token, only_valid)
      invitation_token = Devise.token_generator.digest(self, :invitation_token, original_token)

      invitable = find_or_initialize_with_error_by(:invitation_token, invitation_token)
      unless invitable.persisted? # && Devise.allow_insecure_token_lookup
        invitable = find_or_initialize_with_error_by(:invitation_token, original_token)
      end
      invitable.errors.add(:invitation_token, :invalid) if invitable.invitation_token && invitable.persisted? && !invitable.valid_invitation?
      invitable.errors.add(:invitation_token, :invalid) if invitable.persisted? && invitable.company_users.all? { |cu| cu.active == false }
      invitable.invitation_token = original_token
      invitable unless only_valid && invitable.errors.present?
    end
  end

  # Resend the invitation email and reset the invitation_sent_at
  def resend_invitation
    update_attribute :invitation_sent_at, Time.now.utc
    send_devise_notification(:invitation_instructions, @raw_invitation_token)
  end

  def ensure_authentication_token
    return unless authentication_token.blank?
    self.authentication_token = generate_authentication_token
  end

  def reset_authentication_token!
    self.authentication_token = nil
    ensure_authentication_token
    save validate: false
  end

  private

  def generate_authentication_token
    loop do
      token = Devise.friendly_token
      break token unless User.where(authentication_token: token).first
    end
  end

  def reprocess_avatar
    avatar.reprocess!
    true
  end

  def valid_verification_code?
    errors.add :verification_code, :invalid if verification_code != phone_number_verification
  end

  def reset_verification
    if phone_number_changed?
      assign_attributes(
        phone_number_verified: false,
        phone_number_verification: nil)
    elsif verification_code.present? && verification_code == phone_number_verification
      assign_attributes(
        phone_number_verified: true)
    end
  end
end
