# == Schema Information
#
# Table name: company_users
#
#  id                      :integer          not null, primary key
#  company_id              :integer
#  user_id                 :integer
#  role_id                 :integer
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  active                  :boolean          default("true")
#  last_activity_at        :datetime
#  notifications_settings  :string(255)      default("{}"), is an Array
#  last_activity_mobile_at :datetime
#  tableau_username        :string(255)
#

class CompanyUser < ActiveRecord::Base
  include GoalableModel

  # Defines the method do_search
  include SolrSearchable

  has_paper_trail

  belongs_to :user
  belongs_to :company
  belongs_to :role
  has_many :tasks, dependent: :nullify
  has_many :notifications, dependent: :destroy
  has_many :custom_filters, -> { order 'custom_filters.name ASC' }, dependent: :destroy, as: :owner, inverse_of: :owner
  has_many :filter_settings, dependent: :destroy
  has_many :alerts, class_name: 'AlertsUser', dependent: :destroy
  has_many :satisfaction_surveys

  validates :role_id, presence: true, numericality: true
  validates :company_id, presence: true, numericality: true, uniqueness: { scope: :user_id }

  before_validation :set_default_notifications_settings, on: :create

  has_many :memberships, dependent: :destroy
  has_many :contact_events, dependent: :destroy, as: :contactable

  # Teams-Users relationship
  has_many :teams, -> { where active: true }, through: :memberships, source: :memberable, source_type: 'Team'

  # Campaigns-Users relationship
  has_many :campaigns, -> { where(aasm_state: 'active') }, through: :memberships, source: :memberable, source_type: 'Campaign' do
    def children_of(parent)
      where(memberships: { parent_id: parent.id, parent_type: parent.class.name })
    end
  end

  # Events-Users relationship
  has_many :events, through: :memberships, source: :memberable, source_type: 'Event'

  # Area-User relationship
  has_many :areas, -> { where active: true }, through: :memberships, source: :memberable, source_type: 'Area', after_remove: :remove_child_goals_for

  # BrandPortfolio-User relationship
  has_many :brand_portfolios, -> { where active: true }, through: :memberships, source: :memberable, source_type: 'BrandPortfolio'

  # BrandPortfolio-User relationship
  has_many :brands, -> { where active: true }, through: :memberships, source: :memberable, source_type: 'Brand'

  # Places-Users relationship
  has_many :placeables, as: :placeable, dependent: :destroy
  has_many :places, through: :placeables, after_add: :places_changed

  delegate :name, :email, :phone_number, :time_zone, :avatar, :invited_to_sign_up?,
           :full_address, :country, :state, :city, :street_address, :unit_number, :simple_address,
           :zip_code, :country_name, :state_name, :phone_number_verified?, :unconfirmed_email,
           to: :user
  delegate :is_admin?, to: :role, prefix: false

  NOTIFICATION_SETTINGS_TYPES = %w(event_recap_due event_recap_late event_recap_pending_approval event_recap_rejected new_event_team late_task late_team_task new_comment new_team_comment new_unassigned_team_task new_task_assignment new_campaign)

  NOTIFICATION_SETTINGS_PERMISSIONS = {
    'event_recap_due' => [{ action: :view_list, subject_class: Event }],
    'event_recap_late' => [{ action: :view_list, subject_class: Event }],
    'event_recap_pending_approval' => [{ action: :view_list, subject_class: Event }],
    'event_recap_rejected' => [{ action: :view_list, subject_class: Event }],
    'new_event_team' => [{ action: :view_list, subject_class: Event }],
    'late_task' => [{ action: :index_my, subject_class: Task }],
    'late_team_task' => [{ action: :index_team, subject_class: Task }],
    'new_comment' => [{ action: :index_my, subject_class: Task }, { action: :index_my_comments, subject_class: Task }],
    'new_team_comment' => [{ action: :index_team, subject_class: Task }, { action: :index_team_comments, subject_class: Task }],
    'new_unassigned_team_task' => [{ action: :index_team, subject_class: Task }],
    'new_task_assignment' => [{ action: :index_my, subject_class: Task }],
    'new_campaign' => [{ action: :read, subject_class: Campaign }]
  }

  scope :active, -> { where(active: true) }
  scope :admin, -> { joins(:role).where(roles: { is_admin: true }) }
  scope :by_teams, ->(teams) { joins(:memberships).where(memberships: { memberable_id: teams, memberable_type: 'Team' }) }
  scope :by_campaigns, ->(campaigns) { joins(:memberships).where(memberships: { memberable_id: campaigns, memberable_type: 'Campaign' }) }
  scope :by_events, ->(events) { joins(:memberships).where(memberships: { memberable_id: events, memberable_type: 'Event' }) }

  def  self.in_event_team(event)
    where('company_users.id in ('\
          '    SELECT distinct company_user_id FROM memberships WHERE memberable_id = :event_id AND memberable_type = \'Event\' '\
          ' UNION '\
          '    SELECT distinct company_user_id'\
          '    FROM memberships'\
          '    INNER JOIN teamings ON teamings.teamable_id=:event_id AND teamable_type=\'Event\''\
          '    WHERE memberable_id = teamings.team_id AND memberable_type = \'Team\''\
          ')', event_id: event
    )
  end

  # Returns all users that have at least one of the given notifications
  scope :with_notifications, ->(notifications) { where(notifications.map { |_n| '? = ANY(notifications_settings)' }.join(' OR '), *notifications) }

  scope :with_confirmed_phone_number, -> { joins(:user).where('users.phone_number is not null AND users.phone_number_verified=?', true) }

  scope :with_timezone, -> { joins(:user).where('users.time_zone is not null') }

  scope :with_user_and_role, -> { joins([:role, :user]).includes([:role, :user]) }

  scope :accessible_by_user, ->(user) { where(company_id: user.company_id) }

  searchable do
    integer :id
    integer :company_id

    text :name, stored: true do
      full_name
    end
    text :email

    string :first_name
    string :last_name
    string :email
    string :city
    string :state
    string :country
    string :name do
      full_name
    end

    integer :role_id
    string :role_name

    boolean :active

    string :status do
      active_status
    end

    integer :team_ids, multiple: true
    integer :place_ids, multiple: true
    integer :campaign_ids, multiple: true
  end

  accepts_nested_attributes_for :user, allow_destroy: false, update_only: true

  def self.filters_scope(filters)
    joins(:user)
    .where(active: filters.items_to_show)
    .pluck('company_users.id, users.first_name || \' \' || users.last_name')
  end

  def active_status
    if invited_to_sign_up? && self[:active]
      'Invited'
    else
      active? ? 'Active' : 'Inactive'
    end
  end

  def activate!
    update_attribute(:active, true)
  end

  def deactivate!
    update_attribute(:active, false)
  end

  def find_users_in_my_teams
    @user_in_my_teams ||=
      CompanyUser.joins(:teams)
      .where(teams: { company_id: company_id, id: teams.active.pluck(:id) })
      .where.not(id: id)
      .pluck('DISTINCT company_users.id')
  end

  def accessible_campaign_ids
    @accessible_campaign_ids ||= Rails.cache.fetch("user_accessible_campaigns_#{id}", expires_in: 10.minutes) do
      if is_admin?
        company.campaign_ids
      else
        (
          campaign_ids +
          Campaign.where(company_id: company_id)
                  .joins(:brands)
                  .where(brands: { id: brand_ids })
                  .reorder(nil)
                  .pluck('campaigns.id') +
          Campaign.where(company_id: company_id)
                  .joins(:brand_portfolios)
                  .where(brand_portfolios: { id: brand_portfolio_ids })
                  .reorder(nil)
                  .pluck('campaigns.id')
        ).uniq
      end
    end
  end

  def accessible_brand_portfolios_brand_ids
    BrandPortfoliosBrand.where(brand_portfolio_id: brand_portfolio_ids).pluck('brand_portfolios_brands.brand_id')
  end

  def accessible_brand_ids
    @accessible_brand_ids ||= Rails.cache.fetch("user_accessible_brands_#{id}", expires_in: 10.minutes) do
      is_admin? ? company.brand_ids : (brand_ids + accessible_brand_portfolios_brand_ids).uniq
    end
  end

  def accessible_locations
    @accessible_locations ||= Rails.cache.fetch("user_accessible_locations_#{id}", expires_in: 10.minutes) do
      (
        areas.joins(:places).where(places: { is_location: true }).pluck('places.location_id') +
        places.where(places: { is_location: true }).pluck('places.location_id')
      ).uniq.compact.map(&:to_i)
    end
  end

  def accessible_places
    @accessible_places ||= Rails.cache.fetch("user_accessible_places_#{id}", expires_in: 10.minutes) do
      (
        place_ids +
        areas.joins(:places).pluck('places.id')
      ).flatten.uniq
    end
  end

  def allowed_to_access_place?(place)
    @allowed_places_cache ||= {}
    @allowed_places_cache[place.try(:id) || place.object_id] ||= is_admin? ||
    (
      place.present? &&
      (
        place.location_ids.any? { |location| accessible_locations.include?(location) } ||
        accessible_places.include?(place.id)
      )
    )
  end

  def full_name
    "#{first_name} #{last_name}".strip
  end

  def initial_name
    "#{first_name[0]}#{last_name[0]}".upcase
  end

  def first_name
    if attributes.key?('first_name')
      read_attribute('first_name')
    else
      user.try(:first_name)
    end
  end

  def last_name
    if attributes.key?('last_name')
      read_attribute('last_name')
    else
      user.try(:last_name)
    end
  end

  def role_name
    if attributes.key?('role_name')
      read_attribute('role_name')
    else
      role.try(:name)
    end
  end

  def teams_name
    teams.pluck(:name).join(' ,')
  end

  def dismissed_alert?(alert, version = 1)
    alerts.where(name: alert, version: version).any?
  end

  def allow_notification?(type)
    (type.to_s[-4..-1] != '_sms' || phone_number_verified?) && # SMS notifications only if phone number is confirmed
    notifications_settings.is_a?(Array) && notifications_settings.include?(type.to_s)
  end

  def dismiss_alert(alert, version = 1)
    alerts.find_or_create_by(name: alert, version: version)
  end

  def notification_setting_permission?(type)
    permissions = NOTIFICATION_SETTINGS_PERMISSIONS[type]
    return unless permissions.present?
    permissions.all? { |permission| role.has_permission?(permission[:action], permission[:subject_class]) }
  end

  def filter_setting_present(type, controller_name)
    @filter_settings ||= {}
    @filter_settings[controller_name] ||= filter_settings.find_by(apply_to: controller_name)
    @filter_settings[controller_name].present? && @filter_settings[controller_name].settings.include?(type)
  end

  class << self
    def searchable_params
      [campaign: [], role: [], user: [], team: [], status: [], venue: []]
    end

    def for_dropdown
      joins(:user)
        .order('1')
        .pluck('users.first_name || \' \' || users.last_name as name, company_users.id')
    end

    def for_dropdown_with_role
      joins(:user, :role).order('1')
        .pluck('users.first_name || \' \' || users.last_name as name, company_users.id, roles.name as role')
        .map { |r| [r[0].html_safe, r[1], { 'data-role' => r[2] }] }
    end
  end

  def set_default_notifications_settings
    if notifications_settings.nil? || notifications_settings.empty?
      self.notifications_settings = NOTIFICATION_SETTINGS_TYPES.map { |n| "#{n}_app" }
    end
  end

  private

  def places_changed(_campaign)
    # The cache is cleared in the placeable model
    @accessible_places = nil
    @accessible_locations = nil
    @allowed_places_cache = nil
  end
end
