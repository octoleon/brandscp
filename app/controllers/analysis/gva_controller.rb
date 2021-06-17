class Analysis::GvaController < InheritedResources::Base
  include ExportableController

  respond_to :xls, :pdf, only: :index

  before_action :campaign, except: :index
  before_action :authorize_actions
  before_action :set_scopes, if: -> { action_name == 'report' || request.format.pdf? }

  helper_method :return_path, :report_view_mode, :report_group_by, :report_group_permissions

  def index
  end

  def report_groups
    @goalables = goalables_by_type
    @group_header_data = kpis_headers_data(@goalables)

    render layout: false
  end

  def export_file_name
    "#{controller_name.underscore.downcase}-#{Time.now.strftime('%Y%m%d%H%M%S')}"
  end

  private

  def collection_to_csv
    group_by_title = if report_group_by == 'place'
                       'PLACE/AREA'
                     elsif report_group_by == 'staff'
                       'USER/TEAM'
                     end
    CSV.generate do |csv|
      if report_group_by == 'place' || report_group_by == 'staff'
        csv << [group_by_title, 'METRIC', 'GOAL', 'ACTUAL', 'ACTUAL %', 'PENDING', 'PENDING %']
      else
        csv << ['METRIC', 'GOAL', 'ACTUAL', 'ACTUAL %', 'PENDING', 'PENDING %']
      end
      @goalables_data.each do |goalable|
        goalable[:event_goal].each do |_id, event_goal|
          pending_and_total = (event_goal[:submitted] || 0) + event_goal[:total_count]
          pending = number_with_precision(pending_and_total.round(2), strip_insignificant_zeros: true)
          actual_percentage = event_goal[:completed_percentage]
          pending_percentage = (pending_and_total / event_goal[:goal].value) * 100
          row = [event_goal[:goal].kpi.present? ? event_goal[:goal].kpi.name + (event_goal[:goal].kpis_segment.nil? ? '' : ': ' + event_goal[:goal].kpis_segment.text) : event_goal[:goal].activity_type.name,
                 number_with_precision(event_goal[:goal].value, strip_insignificant_zeros: true),
                 number_with_precision(event_goal[:total_count], strip_insignificant_zeros: true),
                 number_to_percentage(actual_percentage, precision: 2),
                 pending,
                 number_to_percentage(pending_percentage, precision: 2)]
          row.unshift(goalable[:name]) if report_group_by == 'place' || report_group_by == 'staff'
          csv << row
        end
      end
    end
  end

  def prepare_collection_for_export
    @goalables_data = goalables_by_type.map do |goalable|
      set_report_scopes_for(goalable)
      { name: goalable.name, item: goalable, event_goal: view_context.each_events_goal }
    end
  end

  def list_exportable?
    true
  end

  def set_scopes
    set_report_scopes_for(area || place || company_user || team || campaign)
  end

  def campaign
    @campaign ||= current_company.campaigns.find(params[:report][:campaign_id]) if params[:report] && params[:report][:campaign_id].present?
  end

  def area
    @area ||= campaign.areas.find(params[:item_id]) if params[:item_type].present? && params[:item_type] == 'Area'
  end

  def place
    @place ||= Place.find(params[:item_id]) if params[:item_type].present? && params[:item_type] == 'Place'
  end

  def company_user
    @company_user ||= current_company.company_users.find(params[:item_id]) if params[:item_type].present? && params[:item_type] == 'CompanyUser'
  end

  def team
    @team ||= current_company.teams.find(params[:item_id]) if params[:item_type].present? && params[:item_type] == 'Team'
  end

  def authorize_actions
    if params[:report] && params[:report][:campaign_id]
      authorize! :gva_report_campaign, campaign
    else
      authorize! :view_gva_report, Campaign
    end
  end

  def filter_events_scope
    scope = Event.active.accessible_by_user(current_company_user).by_campaigns(campaign.id)
    scope = scope.in_campaign_area(campaign.areas_campaigns.find_by(area: area.id)) unless area.nil?
    scope = scope.in_places([place]) unless place.nil?
    scope = scope.with_user_in_team(company_user).uniq unless company_user.nil?
    scope = scope.with_user_in_team(team.users.active.ids).uniq unless team.nil?
    scope
  end

  def filter_venues_scope
    if area.present?
      Venue.in_campaign_areas(@campaign, [params[:item_id]])
    elsif place.present?
      if place.is_location?
        Venue.joins("INNER JOIN locations_places ON locations_places.place_id=venues.place_id AND locations_places.location_id=#{place.location_id}")
      else
        Venue.where(place_id: place.id)
      end
    elsif company_user.present?
      Venue.in_campaign_scope(@campaign).joins(:activities).where(activities: { company_user_id: company_user.id })
    elsif team.present?
      Venue.in_campaign_scope(@campaign).joins(:activities).where(activities: { company_user_id: team.users.ids })
    else
      Venue.in_campaign_scope(@campaign)
    end
  end

  def goalables_by_type
    if report_group_by == 'campaign'
      campaign.goals
    elsif report_group_by == 'place'
      campaign.children_goals.for_areas_and_places(
        campaign.areas.accessible_by_user(current_company_user).pluck('areas.id'),
        campaign.places.select { |place| current_company_user.allowed_to_access_place?(place) }.map(&:id))
    else
      campaign.children_goals.for_users_and_teams
    end.select('goalable_id, goalable_type').where('value IS NOT NULL').includes(:goalable).group('goalable_id, goalable_type').map(&:goalable).sort_by(&:name)
  end

  def set_report_scopes_for(goalable)
    if %w(csv pdf).include?(params[:format]) && (report_group_by == 'place' || report_group_by == 'staff')
      @area, @place, @company_user, @team = nil, nil, nil, nil
      params.merge!(item_type: goalable.class.name, item_id: goalable.id)
    end
    @events_scope = filter_events_scope
    @venues_scope = filter_venues_scope
    @group_header_data = {}
    goals = if area
              area.goals.in(campaign)
    elsif place
              place.goals.in(campaign)
    elsif company_user
              company_user.goals.in(campaign)
    elsif team
              team.goals.in(campaign)
    else
      campaign.goals.base
    end

    sub_query = Campaign.connection.unprepared_statement { campaign.activity_types.active.select(:id).to_sql }

    goals = goals.where('goals.value is not null and goals.value <> 0')
    goals_activities =  goals.joins(:activity_type).where("activity_type_id in (#{sub_query})").includes(:activity_type)
    goals_kpis = goals.joins(:kpi).where(kpi_id: campaign.active_kpis).includes(:kpi)
    # Following KPIs should be displayed in this specific order at the beginning. Rest of KPIs and Activity Types should be next in the list ordered by name
    promotables = ['Events', 'Promo Hours', 'Expenses', 'Samples', 'Interactions', 'Impressions']
    @goals = (goals_kpis + goals_activities).sort_by { |g| g.kpi_id.present? ? (promotables.index(g.kpi.name) || ('A' + g.kpi.name)).to_s : g.activity_type.name }
  end

  def kpis_headers_data(goalables)
    if goalables.is_a?(Campaign)
      goals = Hash[campaign.goals.base.with_value.where(kpi_id: [Kpi.events.id, Kpi.promo_hours.id, Kpi.expenses.id, Kpi.samples.id]).map do |g|
        ["#{g.goalable_type}_#{g.goalable_id}_#{g.kpi_id}", g]
      end]
      goalables = [goalables]
    else
      goals = Hash[campaign.children_goals.with_value.where(kpi_id: [Kpi.events.id, Kpi.promo_hours.id, Kpi.expenses.id, Kpi.samples.id]).where('goalable_type || goalable_id in (?)', goalables.map { |g| "#{g.class.name}#{g.id}" }).map do |g|
        ["#{g.goalable_type}_#{g.goalable_id}_#{g.kpi_id}", g]
      end]
    end

    goal_keys = goals.keys
    items = {}
    goalables.each do |goalable|
      %w(promo_hours events samples expenses).each do |kpi|
        items[goalable.class.name] ||= {}
        items[goalable.class.name][kpi] ||= []
        items[goalable.class.name][kpi].push goalable if goal_keys.include?("#{goalable.class.name}_#{goalable.id}_#{Kpi.send(kpi).id}")
      end
    end
    queries = ActiveRecord::Base.connection.unprepared_statement do
      items.map do |goalable_type, goaleables_ids|
        %w(promo_hours events samples expenses).map do |kpi|
          next unless goaleables_ids[kpi].any?
          events_scope = campaign.events.active.where(aasm_state: %w(approved rejected submitted)).group('1').reorder(nil)

          query =
            if goalable_type == 'Area'
              events_scope.in_campaign_areas(campaign, goaleables_ids[kpi]).select("ARRAY[areas_places.area_id::varchar, '#{goalable_type}'], '{KPI_NAME}', {KPI_AGGR}")
            elsif goalable_type == 'Place'
              events_scope.in_places(goaleables_ids[kpi]).select("ARRAY[places.id::varchar, '#{goalable_type}'], '{KPI_NAME}', {KPI_AGGR}")
            elsif goalable_type == 'CompanyUser'
              events_scope.with_user_in_team(goaleables_ids[kpi]).select("ARRAY[memberships.company_user_id::varchar, '#{goalable_type}'], '{KPI_NAME}', {KPI_AGGR}")
            elsif goalable_type == 'Team'
              events_scope.with_team(goaleables_ids[kpi]).select("ARRAY[teamings.id::varchar, '#{goalable_type}'], '{KPI_NAME}', {KPI_AGGR}")
            else
              events_scope.select("ARRAY[events.campaign_id::varchar, 'Campaign'], '{KPI_NAME}', {KPI_AGGR}")
            end

          if kpi == 'promo_hours'
            goaleables_ids['promo_hours'].any? ? query.to_sql.gsub('{KPI_NAME}', 'PROMO HOURS').gsub('{KPI_AGGR}', 'SUM(events.promo_hours)') : nil
          elsif kpi == 'events'
            goaleables_ids['events'].any? ? query.to_sql.gsub('{KPI_NAME}', 'EVENTS').gsub('{KPI_AGGR}', 'COUNT(DISTINCT events.id)') : nil
          elsif kpi == 'samples'
            goaleables_ids['samples'].any? ? query.joins(results: :form_field).where(form_fields: { kpi_id: Kpi.samples.id }).to_sql.gsub('{KPI_NAME}', 'SAMPLES').gsub('{KPI_AGGR}', 'SUM(form_field_results.scalar_value)') : nil
          elsif kpi == 'expenses'
            goaleables_ids['expenses'].any? ? query.joins(:event_expenses).to_sql.gsub('{KPI_NAME}', 'EXPENSES').gsub('{KPI_AGGR}', 'SUM(event_expenses.amount)') : nil
          end
        end
      end.flatten.compact
    end

    if queries.any?
      ActiveRecord::Base.connection.unprepared_statement do
        Hash[ActiveRecord::Base.connection.select_all("
          SELECT keys[1] as id, keys[2] as type, promo_hours, events, samples, expenses FROM crosstab('#{queries.join(' UNION ALL ').gsub('\'', '\'\'')} ORDER by 1',
            'SELECT unnest(ARRAY[''PROMO HOURS'', ''EVENTS'', ''SAMPLES'', ''EXPENSES''])') AS ct(keys varchar[], promo_hours numeric, events numeric, samples numeric, expenses numeric)").map do |r|

          r['events'] = if goals["#{r['type']}_#{r['id']}_#{Kpi.events.id}"].present?
                          r['events'].to_f * 100 / goals["#{r['type']}_#{r['id']}_#{Kpi.events.id}"].value
          else
            nil
          end

          r['promo_hours'] = if goals["#{r['type']}_#{r['id']}_#{Kpi.promo_hours.id}"].present?
                               r['promo_hours'].to_f * 100 / goals["#{r['type']}_#{r['id']}_#{Kpi.promo_hours.id}"].value
          else
            nil
          end

          r['samples'] = if goals["#{r['type']}_#{r['id']}_#{Kpi.samples.id}"].present?
                           r['samples'].to_f * 100 / goals["#{r['type']}_#{r['id']}_#{Kpi.samples.id}"].value
          else
            nil
          end

          r['expenses'] = if goals["#{r['type']}_#{r['id']}_#{Kpi.expenses.id}"].present?
                            r['expenses'].to_f * 100 / goals["#{r['type']}_#{r['id']}_#{Kpi.expenses.id}"].value
          else
            nil
          end

          ["#{r['type']}#{r['id']}", r]
        end]
      end
    else
      {}
    end
  end

  def report_group_by
    @_group_by ||= if params[:report].present? && params[:report][:group_by].present?
                     params[:report][:group_by]
    else
      if can?(:gva_report_campaigns, Campaign)
        'campaign'
      elsif can?(:gva_report_places, Campaign)
        'place'
      elsif can?(:gva_report_users, Campaign)
        'staff'
      end
    end
  end

  def report_view_mode
    @_view_mode ||= if params[:report].present? && params[:report][:view_mode].present?
                      params[:report][:view_mode]
    else
      'graph'
    end
  end

  def report_group_permissions
    permissions = []
    permissions.push(%w(Campaign campaign)) if can?(:gva_report_campaigns, Campaign)
    permissions.push(%w(Place place)) if can?(:gva_report_places, Campaign)
    permissions.push(%w(Staff staff)) if can?(:gva_report_users, Campaign)
    permissions
  end

  def return_path
    analysis_path
  end
end
