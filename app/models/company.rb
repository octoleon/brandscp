# == Schema Information
#
# Table name: companies
#
#  id                 :integer          not null, primary key
#  name               :string(255)
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  timezone_support   :boolean
#  settings           :hstore
#  expense_categories :text
#

class Company < ActiveRecord::Base
  attr_accessor :admin_email
  attr_accessor :no_create_admin

  store_accessor :settings, :event_alerts_policy, :brand_ambassadors_role_ids,
                 :ytd_dates_range, :auto_match_events

  # Should go after the `store :settings...` line
  include KbmgConfigurable

  has_many :company_users, dependent: :destroy
  has_many :teams, dependent: :destroy
  has_many :campaigns, dependent: :destroy
  has_many :roles, dependent: :destroy
  has_many :venues, dependent: :destroy
  has_many :brand_portfolios, dependent: :destroy
  has_many :events, dependent: :destroy
  has_many :areas, dependent: :destroy
  has_many :brands, dependent: :destroy
  has_many :date_ranges, dependent: :destroy
  has_many :day_parts, dependent: :destroy
  has_many :contacts, dependent: :destroy
  has_many :kpis, dependent: :destroy
  has_many :reports, dependent: :destroy
  has_many :activity_types, dependent: :destroy
  has_many :custom_activity_forms, dependent: :destroy  
  has_many :data_extracts, dependent: :destroy
  has_many :brand_ambassadors_visits, -> { order 'brand_ambassadors_visits.start_date ASC' },
           class_name: 'BrandAmbassadors::Visit', dependent: :destroy
  has_many :brand_ambassadors_documents, -> { order('attached_assets.file_file_name ASC') },
           class_name: 'BrandAmbassadors::Document', as: :attachable,
           inverse_of: :attachable, dependent: :destroy  do
    def root_children
      where(folder_id: nil)
    end
  end
  has_many :document_folders, -> { order('lower(document_folders.name) ASC') } do
    def root_children
      where(parent_id: nil)
    end
  end
  has_many :custom_filters, dependent: :destroy, as: :owner, inverse_of: :owner
  has_many :custom_filters_categories, dependent: :destroy

  has_many :tags, -> { order('tags.name ASC') }, autosave: true, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :admin_email, presence: true, on: :create, unless: :no_create_admin

  validates :admin_email, format: { with: /\A[^@\s]+@([^@\s]+\.)+[^@\s]+\z/ }, allow_blank: true

  after_create :create_admin_role_and_user

  before_save do
    self.expense_categories ||= "Uncategorized\n Entertainment\nFuel/Mileage\n"\
                                "Lodging\nMeals\nOther\nPhone\nTransportation"
  end

  YTD_DEFAULT = 1
  YTD_JULY1_JUNE30 = 2 # Alternative YTD from July 1 to June 30

  def self.current=(company)
    Thread.current[:company] = company
  end

  def self.current
    Thread.current[:company]
  end

  def brand_ambassadors_users
    @brand_ambassadors_users ||= begin
      s = company_users.active
      s = s.where(role_id: brand_ambassadors_role_ids) if brand_ambassadors_role_ids.any?
      s
    end
  end

  # Return the value stored in "settings" or the default
  # Notification::EVENT_ALERT_POLICY_TEAM if not set
  def event_alerts_policy
    (super || Notification::EVENT_ALERT_POLICY_TEAM).to_i
  end

  def brand_ambassadors_role_ids
    (super || '').split(',').map(&:to_i)
  end

  def brand_ambassadors_role_ids=(roles)
    super roles.reject { |r| r.nil? || r == '' }.join(',')
  end

  def ytd_dates_range
    (super || YTD_DEFAULT).to_i
  end

  def auto_match_events
    (super || 1).to_i
  end

  def company_id
    id
  end

  def team_member_options
    Company.connection.unprepared_statement do
      ActiveRecord::Base.connection.select_all("
        #{company_users.active.select('company_users.id, users.first_name || \' \' || users.last_name as name, \'company_user\' as type').joins(:user).to_sql}
        UNION ALL
        #{teams.active.select('teams.id, teams.name, \'team\' as type').to_sql}
        ORDER BY name ASC
      ").map { |r| [r['name'], "#{r['type']}:#{r['id']}", { class: r['type'] }] }
    end
  end

  def late_event_end_date
    if timezone_support?
      Timeliness.parse(2.days.ago.strftime('%Y-%m-%d 23:59:59'), zone: 'UTC')
    else
      2.days.ago.end_of_day
    end
  end

  def due_event_start_date
    if timezone_support?
      Timeliness.parse(Date.yesterday.strftime('%Y-%m-%d 00:00:00'), zone: 'UTC')
    else
      Date.yesterday.beginning_of_day
    end
  end

  def due_event_end_date
    if timezone_support?
      Timeliness.parse(Time.now.strftime('%Y-%m-%d 00:00:00'), zone: 'UTC')
    else
      Time.now.in_time_zone(Time.zone)
    end
  end

  def late_task_date
    if timezone_support?
      Timeliness.parse(Date.yesterday.strftime('%Y-%m-%d 00:00:00'), zone: 'UTC')
    else
      Date.yesterday.beginning_of_day
    end
  end

  private

  def create_admin_role_and_user
    return unless admin_email
    role = roles.create(name: 'Super Admin', is_admin: true)
    if (user = User.where(["lower(users.email) = '%s'", admin_email.downcase]).first)
      new_company_user = company_users.build(role_id: role.id, user: user)
      new_company_user.save validate: false
      UserMailer.delay.company_existing_admin_invitation(user.id, id)
    else
      new_user = User.create(email: admin_email, first_name: 'Admin', last_name: 'User', inviting_user: true)
      company_users.create(role_id: role.id, user: new_user)
      new_user.skip_invitation = true
      new_user.invite!
      new_user.reload.update_attributes(invitation_sent_at: Time.now.utc)
      UserMailer.delay.company_admin_invitation(new_user.id)
    end
  end
end
