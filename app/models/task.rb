# == Schema Information
#
# Table name: tasks
#
#  id              :integer          not null, primary key
#  event_id        :integer
#  title           :string(255)
#  due_at          :datetime
#  completed       :boolean          default("false")
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  created_by_id   :integer
#  updated_by_id   :integer
#  active          :boolean          default("true")
#  company_user_id :integer
#

class Task < ActiveRecord::Base
  track_who_does_it

  belongs_to :event
  belongs_to :company_user
  has_many :comments, -> { order 'comments.created_at ASC' }, as: :commentable

  after_save :create_notifications

  delegate :full_name, to: :company_user, prefix: :user, allow_nil: true
  delegate :campaign_name, :place_id, to: :event, allow_nil: true

  validates :title, presence: true
  validates :event_id, numericality: true, allow_nil: true, if: :event_id
  validates :event_id, presence: true, unless: :company_user_id
  validates :company_user_id, numericality: true, allow_nil: true
  validates :company_user_id, presence: true, unless: :event_id

  scope :incomplete, -> { where(completed: false) }
  scope :active, -> { where(active: true) }
  scope :by_companies, ->(companies) { where(events: { company_id: companies }).joins(:event) }
  scope :late, -> { where(['due_at is not null and due_at < ? and completed = ?', Date.today, false]) }
  scope :due_today, -> { where(['due_at BETWEEN ? and ? and completed = ?', Date.today, Date.tomorrow, false]) }
  scope :due_today_and_late, -> { where(['due_at is not null and due_at <= ? and completed = ?', Date.today.end_of_day, false]) }
  scope :assigned_to, ->(users) { where(company_user_id: users) }
  scope :accessible_by_user, ->(company_user) { where(company_id: company_user.company_id) }
  scope :filters_between_dates, ->(start_date, end_date) { where(due_at: DateTime.parse(start_date)..DateTime.parse(end_date)) }

  belongs_to :created_by, class_name: 'User'
  delegate :full_name, to: :created_by, prefix: true, allow_nil: true

  searchable do
    integer :id
    text :name, stored: true do
      title
    end

    integer :company_user_id, references: CompanyUser
    integer :event_id
    integer :company_id do
      company_id
    end

    integer :place_id

    integer :location, multiple: true do
      event.place.location_ids if event.present? && event.place.present?
    end

    integer :team_members, multiple: true do
      team_members = []
      team_members.push event.memberships.map(&:company_user_id) + event.teams.map { |t| t.memberships.map(&:company_user_id) } if event.present?
      team_members.push task_company_user.id if task_company_user.present? && task_company_user.id != company_user_id
      team_members.flatten.uniq
    end

    integer :campaign_id do
      campaign_id
    end

    time :due_at, trie: true
    time :last_activity

    string :user_name do
      company_user.try(:full_name)
    end

    boolean :completed
    string :status do
      if event.nil? || event.active?
        active? ? 'Active' : 'Inactive'
      else
        'Inactive Event'
      end
    end

    string :statusm, multiple: true do
      status = []
      status.push active? ? 'Active' : 'Inactive'
      status.push assigned? ? 'Assigned' : 'Unassigned'
      status.push completed? ? 'Complete' : 'Incomplete'
      status
    end
  end

  def due_today?
    due_at.to_date <= Date.today && due_at.to_date >= Date.today unless due_at.nil?
  end

  def task_company_user
    CompanyUser.find_by(company_id: created_by.current_company.id, user_id: created_by_id) if created_by.present? && created_by.current_company.present?
  end

  def late?
    !completed? && due_at.to_date <= Date.yesterday unless due_at.nil?
  end

  def activate!
    update_attribute :active, true
  end

  def deactivate!
    update_attribute :active, false
  end

  def assigned?
    company_user_id.present?
  end

  def last_activity
    updated_at
  end

  def statuses
    status = []
    status.push active? ? 'Active' : 'Inactive'
    status.push assigned? ? 'Assigned' : 'Unassigned'
    status.push completed? ? 'Complete' : 'Incomplete'
    status.push 'Late' if late?
    status.push 'Due' if due_today?
    status
  end

  def company_id
    # For those tasks created from Task section,
    # company ID will be assigned from user
    event.try(:company_id) || company_user.try(:company_id)
  end

  def campaign_id
    # For those tasks created from Task section,
    # campaign ID will be nil
    event.try(:campaign_id)
  end

  def task_statuses
    statuses.map(&:humanize).join(', ') if statuses.present?
  end

  class << self
    # We are calling this method do_search to avoid conflicts with other gems like meta_search used by ActiveAdmin
    def do_search(params, include_facets = false)
      solr_search(include: [{ company_user: :user }, :event]) do
        current_company = Company.current || Company.new
        # Filter by user permissions
        company_user = params[:current_company_user]
        if company_user.present?
          current_company = company_user.company
          unless company_user.role.is_admin?
            any_of do
              with(:campaign_id, company_user.accessible_campaign_ids + [0])
              with(:team_members, [company_user.id] + [0])
              all_of do
                with(:campaign_id, nil)
                with(:company_user_id, company_user.id)

                any_of do
                  locations = company_user.accessible_locations
                  places_ids = company_user.accessible_places
                  with(:campaign_id, nil)
                  with(:place_id, places_ids + [0])
                  with(:location, locations + [0])
                end
              end
            end
          end
        end

        with :id, params[:id] if params.key?(:id) && params[:id]
        with :id, params[:task] if params.key?(:task) && params[:task]
        with :company_id, params[:company_id]
        with :campaign_id, params[:campaign]  if params.key?(:campaign) && params[:campaign]
        with :company_user_id, params[:user] if params.key?(:user) && params[:user].present?
        with :event_id, params[:event_id] if params.key?(:event_id) && params[:event_id]
        with :team_members, params[:team_members] if params.key?(:team_members) && params[:team_members]

        with :company_user_id, CompanyUser.joins(:teams).where(teams: { id: params[:team] }).map(&:id) if params.key?(:team) && !params[:team].empty?
        without :company_user_id, params[:not_assigned_to] if params.key?(:not_assigned_to) && !params[:not_assigned_to].empty?

        if params.key?(:status) && params[:status]
          late = params[:status].delete('Late')
          with(:status, params[:status].uniq) unless params[:status].empty?

          params[:late] = true if late.present?
        end

        if params.key?(:task_status) && params[:task_status]
          late = params[:task_status].delete('Late')
          any_of do
            with :statusm, params[:task_status].uniq unless params[:task_status].empty?
            if late.present?
              all_of do
                with(:due_at).less_than(current_company.late_task_date)
                with(:completed, false)
              end
            end
          end
        end

        if params[:late]
          with(:due_at).less_than(current_company.late_task_date)
          with :completed, false
        end

        if params[:start_date].present? && params[:end_date].present?
          params[:start_date] = Array(params[:start_date])
          params[:end_date] = Array(params[:end_date])
          d1 = Timeliness.parse(params[:start_date][0], zone: :current).beginning_of_day
          d2 = Timeliness.parse(params[:end_date][0], zone: :current).end_of_day
          with :due_at, d1..d2
        elsif params[:start_date].present?
          d = Timeliness.parse(params[:start_date][0], zone: :current)
          with :due_at, d.beginning_of_day..d.end_of_day
        end

        if include_facets
          facet :campaign_id
          facet :status do
            row(:late) do
              with(:due_at).less_than(current_company.late_task_date)
              with :completed, false
            end
            row(:unassigned) do
              with(:statusm, 'Unassigned')
            end
            row(:assigned) do
              with(:statusm, 'Assigned')
            end
            row(:incomplete) do
              with(:statusm, 'Incomplete')
            end
            row(:complete) do
              with(:statusm, 'Complete')
            end
            row(:active) do
              with(:statusm, 'Active')
            end
            row(:inactive) do
              with(:statusm, 'Inactive')
            end
          end
          facet :company_user_id
        end

        order_by(params[:sorting] || :due_at, params[:sorting_dir] || :asc)
        paginate page: (params[:page] || 1), per_page: (params[:per_page] || 30)
      end
    end

    def searchable_params
      [campaign: [], user: [], team: [], start_date: [], end_date: [],
       task_status: [], status: [], task: []]
    end

    def report_fields
      {
        title:       { title: 'Title' },
        due_at:      { title: 'Start time' },
        active:      { title: 'Active State' },
        task_status: { title: 'Event Status' }
      }
    end

    def search_params_for_scope(scope, company_user)
      if scope == 'user'
        { user: [company_user.id] }
      elsif scope == 'teams'
        params = { not_assigned_to: [company_user.id] }
        unless company_user.company.event_alerts_policy == Notification::EVENT_ALERT_POLICY_ALL
          params.merge!(team_members: [company_user.id])
        end
        params
      else
        {}
      end
    end
  end

  private

  def create_notifications
    return unless (id_changed? || company_user_id_changed?) && company_user_id.present?
    # Delete notification for previous task owner
    if !id_changed? && company_user_id_was.present? && company_user_id != company_user_id_was
      notification = CompanyUser.find(company_user_id_was).notifications.where("params->'task_id' = (?)", id.to_s).first
      notification.destroy if notification.present?
    end

    return unless event.present? && company_user.allowed_to_access_place?(event.place)

    # New task with assigned user or assigning user to existing task
    Notification.new_task(company_user, self)
  end
end
