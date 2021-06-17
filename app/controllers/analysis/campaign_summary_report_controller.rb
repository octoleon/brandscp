class Analysis::CampaignSummaryReportController < InheritedResources::Base
  include ExportableController

  respond_to :pdf, only: :export_results

  helper_method :return_path, :collection_count
  before_action :initialize_campaign
  set_callback :export
  respond_to :csv, only: [:index]

  FIELD_TYPE = ['FormField::Number', 'FormField::Currency', 'FormField::Calculation',
                'FormField::LikertScale', 'FormField::Percentage', 'FormField::Checkbox',
                'FormField::Radio', 'FormField::Dropdown', 'FormField::Brand']

  delegate :count, to: :collection, prefix: true

  def export_results
    respond_to do |format|
      format.pdf do
        render pdf: pdf_form_file_name,
               layout: 'application.pdf',
               disposition: 'attachment',
               show_as_html: params[:debug].present?
      end
      format.html do
        render layout: 'application.pdf',
               disposition: 'attachment',
               show_as_html: params[:debug].present?
      end
    end
  end

  def report
    render layout: false
  end

  def result
    render layout: false
  end

  def show_all
    @modal_dialog_title = params[:title]
    @form_field_type = params[:type]
    @result = params[:result]
    render layout: false
  end

  def permitted_search_params
    Event.searchable_params
  end

  def search_params
    @search_params || (super.tap do |p|
      p[:sorting] ||= Event.search_start_date_field
      p[:sorting_dir] ||= 'asc'
      p[:search_permission] = :index_results
      p[:search_permission_class] = EventData
      p[:event_data_stats] = true
    end)
  end

  def results_scope
    cf = CustomFilter.where(id: params[:cfid]).first if params['cfid'].present?
    results = scope_with(params)

    unless cf.nil? || cf.filters.to_s.empty?
      filter_params = cf.to_params
      results = results.merge(scope_with(filter_params))
    end

    results
  end

  def items
    render layout: false
  end

  def collection
    @campaign_ids.present? ? Event.where(campaign_id: @campaign_ids).merge(results_scope) : []
  end

  protected

  def return_path
    analysis_path
  end

  def collection_to_csv
    params = @_export.params if @_exports.present?
    initialize_campaign
    (CSV.generate do |csv|
      generate_results_csv.each do |_, row|
        csv << row
      end
    end).encode('WINDOWS-1252', :undef => :replace, :replace => '')
  end

  private

    def scope_with(parameters)
      s = Event.where(company_id: current_company_user.company_id, active: true).uniq
      s = s.in_areas(parameters['area']) if parameters['area'].present?
      s = s.in_user_accessible_locations(current_company_user) unless current_company_user.is_admin?
      s = in_places(s, parameters['place']) if parameters['place'].present?
      s = with_event_status(s, parameters['event_status']) if parameters['event_status'].present?
      s = s.filters_between_dates(parameters['start_date'].to_s, parameters['end_date'].to_s) if parameters['start_date'].present? && parameters['end_date'].present?
      s = s.joins('LEFT JOIN brands_campaigns ON brands_campaigns.campaign_id=events.campaign_id')
              .where("brands_campaigns.brand_id IN (#{parameters['brand'].join(', ')})").uniq if parameters['brand'].present?

      user_ids = []
      user_ids = Team.joins(:memberships).where(id: parameters['team']).pluck("memberships.company_user_id") if parameters['team'].present?
      user_ids = user_ids + parameters['user'] if parameters['user'].present?
      user_ids = user_ids.uniq if user_ids.present?

      s = s.joins('LEFT JOIN memberships AS member_events ON member_events.memberable_type=\'Event\'')
              .where("member_events.memberable_id = events.id AND member_events.company_user_id IN (#{user_ids.join(', ')})").uniq if user_ids.present?
      s
    end

    def initialize_results_csv
      hash_result = { titles: ['Campaign', 'Event Status'] }
      last_campaign_id, campaign_name = nil, nil
      collection.joins(:campaign).order('campaigns.name, events.created_at').distinct(false).reduce(hash_result) do |hash, event|
        campaign_name = event.campaign_id != last_campaign_id ? event.campaign.name : campaign_name
        last_campaign_id = event.campaign_id
        hash[event.id] = [campaign_name, event.event_status_complete]
        hash
      end
    end

    def generate_results_csv
      hash_results = initialize_results_csv
      kpis_per_campaigns_values = kpis_per_campaigns

      kpis_per_campaigns_values.each do |campaigns_with_kpis|
        kpis_ids = campaigns_with_kpis['kpis'].collect(&:id)
        campaigns_with_kpis['campaigns'].order(:name).each do |campaign|
          form_fields = kpis_ids.collect { |id| campaign.form_fields.detect { |x| x.kpi_id == id } } # Keep the fields order from the on-screen app report
          form_fields.each do |form_field|
            if form_field.present? && FIELD_TYPE.include?(form_field.type)
              form_field.csv_results(campaign, @event_scope, hash_results)
            end
          end
        end
      end

      hash_results
    end

    def pdf_form_file_name
      "campaign_summary_report-#{Time.now.strftime('%Y%m%d%H%M%S')}"
    end

    def set_cache_header
      response.headers['Cache-Control'] = 'private, max-age=0, no-cache'
    end

    def initialize_campaign
      @event_scope = results_scope

      @group_by ||= if params[:report] && params[:report][:summary_group_by].present?
                      params[:report][:summary_group_by]
                    elsif params[:summary_group_by].present?
                      params[:summary_group_by]
                    else
                      nil
                    end

      @campaign_ids ||= if params[:report] && params[:report][:campaign_id].present?
                          params[:report][:campaign_id].reject(&:empty?)
                        elsif params[:campaign_summary].present?
                          params[:campaign_summary].split(',')
                        else
                          nil
                        end

      unless @campaign_ids.nil?
        @campaigns = current_company.campaigns.where(id: @campaign_ids).preload(:kpis, :form_fields)
        calculate_kpi_values unless params['format'].present? && params['format'] == 'csv'
      end
    end

    def kpis_per_campaigns
      # First: Group campaigns by KPIs
      campaign_ids_per_kpis = {}
      if @campaigns.any?
        @campaigns.each do |campaign|
          campaign.kpis.pluck(:id).each do |kpi_id|
            if campaign_ids_per_kpis[kpi_id].nil?
              campaign_ids_per_kpis[kpi_id] = [campaign.id]
            else
              campaign_ids_per_kpis[kpi_id] << campaign.id
            end
          end
        end
      end

      # Second: Group KPIs by Campaigns
      common_kpi_ids_grouped_by_campaigns = []
      campaign_ids_per_kpis.each do |kpi|
        added = false
        common_kpi_ids_grouped_by_campaigns.each do |common_kpi_id|
          if common_kpi_id['campaigns'] == kpi[1]
            common_kpi_id['kpis'] << kpi[0]
            added = true
          end
        end
        if !added
          common_kpi_ids_grouped_by_campaigns << {
            'campaigns' => kpi[1],
            'kpis' => [kpi[0]]
          }
        end
      end

      # Third: order the list from most campaigns to least campaigns
      common_kpi_ids_grouped_by_campaigns.sort_by!{ |x| x['campaigns'].length }.reverse!

      # Fourth: fetch the KPIs and order them appropriately
      @common_kpis_per_campaigns = []
      common_kpi_ids_grouped_by_campaigns.each do |common_kpi_id|
        @common_kpis_per_campaigns << {
          'campaigns' => Campaign.where(id: common_kpi_id['campaigns']),
          'kpis' => Kpi.where(id: common_kpi_id['kpis']).order(%q{
                         case kpi_type
                           when 'number' then 1
                           else 2
                         end
                       })
        }
      end

      @common_kpis_per_campaigns
    end

    def calculate_kpi_values
      @kpis_with_values = []
      kpis_per_campaigns_values = kpis_per_campaigns
      all_campaigns_share_kpis = false
      all_campaigns_kpis = {}
      if !kpis_per_campaigns_values.first.nil? && kpis_per_campaigns_values.first['campaigns'].length == @campaigns.length
        all_campaigns_share_kpis = true
        all_campaigns_kpis = {
          campaigns: kpis_per_campaigns_values.first['campaigns'],
          kpi_values: [{
            kpi: Kpi.new(name: 'Events'),
            form_field: FormField.new(name: '# of Events', type: 'FormField::Number'),
            values: calculate_event_statuses(@group_by)
          }]
        }
      else
        @kpis_with_values << {
          campaigns: @campaigns,
          kpi_values: [{
            kpi: Kpi.new(name: 'Events'),
            form_field: FormField.new(name: '# of Events', type: 'FormField::Number'),
            values: calculate_event_statuses(@group_by)
          }]
        }
      end

      kpis_per_campaigns_values.each_with_index do |campaigns_with_kpis, i|
        current_obj = {
          campaigns: campaigns_with_kpis['campaigns'],
          kpi_values: []
        }
        if i == 0 && all_campaigns_share_kpis
          current_obj = all_campaigns_kpis
        end

        campaigns_with_kpis['kpis'].each do |kpi|
          values = []
          is_age = kpi.name.downcase == 'age'
          is_number = kpi.kpi_type == 'number'
          ff = nil
          campaigns_with_kpis['campaigns'].each_with_index do |kampaign, index|
            # TODO: do we need to do a .each on form_fields? (see that there's a .first call)
            current_ff = kampaign.form_fields.where(kpi_id: kpi.id).first
            if index == 0
              ff = current_ff
              if is_number
                values = ff.grouped_results(kampaign, @event_scope = results_scope, @group_by)
              else
                values = ff.grouped_results(kampaign, @event_scope = results_scope)
              end
            else
              if is_number
                results = current_ff.grouped_results(kampaign, @event_scope = results_scope, @group_by)
              else
                results = current_ff.grouped_results(kampaign, @event_scope = results_scope)
              end
              results.each_with_index do |v, i|
                if values.respond_to?(:each)
                  has_val = false
                  values.each do |val|
                    if val[0] == v[0]
                      val[1] = val[1].to_f + v[1].to_f
                      has_val = true
                      break
                    end
                  end
                  values << v unless has_val
                end
              end
            end
          end
          values.sort! { |a, b| a[0] <=> b[0] } unless [nil, 'status'].include?(@group_by)
          if is_age
            total = 0
            values.map { |v| total += v[1] }
            values.map { |v| v[1] = (v[1].to_f / total.to_f * 100.0).round(2) }
          end
          values = Hash[values] if is_age || is_number
          current_obj[:kpi_values] << {
            kpi: kpi,
            form_field: ff,
            values: values
          }
        end
        @kpis_with_values << current_obj
      end

      @kpis_with_values
    end

    def in_places(s, places)
      places_list = Place.where(id: places)
      s = s.where(
        'events.place_id in (?) or events.place_id in (
            select place_id FROM locations_places where location_id in (?)
        )',
        places_list.map(&:id).uniq + [0],
        places_list.select(&:is_location?).map(&:location_id).compact.uniq + [0])
      s
    end

    def with_event_status(s, status)
      status = status.map(&:downcase)
      if status.include?('due') || status.include?('late')
        condition = ''
        special_conditions, in_conditions = [], []
        date_field = current_company.timezone_support? ? :local_end_at : :end_at
        # due_date = current_company.due_event_end_date.utc
        # late_date = current_company.late_event_end_date.utc
        if current_company.timezone_support?
          today = Timeliness.parse(Time.now.strftime('%Y-%m-%d 00:00:00'), zone: 'UTC')
          yesterday = Timeliness.parse(Date.yesterday.strftime('%Y-%m-%d 00:00:00'), zone: 'UTC')
          twodaysago = Timeliness.parse(2.days.ago.strftime('%Y-%m-%d 23:59:59'), zone: 'UTC')
        else
          today = Time.now.in_time_zone(Time.zone)
          yesterday = Date.yesterday.beginning_of_day
          twodaysago = 2.days.ago.end_of_day
        end
        status.each do |sts|
          case sts
          when 'due'
            special_conditions.push("(events.aasm_state = 'unsent' AND events.#{date_field} <= '#{today}' AND events.#{date_field} >= '#{yesterday}')")
          when 'late'
            special_conditions.push("(events.aasm_state = 'unsent' AND events.#{date_field} <= '#{twodaysago}')")
          else
            in_conditions.push("'#{sts}'")
          end
        end
        condition += "events.aasm_state IN (#{in_conditions.join(',')})" if in_conditions.present?
        condition += ' OR ' if in_conditions.present? && special_conditions.present?
        condition += "#{special_conditions.join(' OR ')}" if special_conditions.present?
        s = s.where(condition)
      else
        s = s.where(aasm_state: status)
      end
      s
    end

    def calculate_event_statuses(group_by = nil)
      data = {}
      total = 0
      if group_by == 'campaign'
        collection.pluck(:id, :campaign_id).each do |ev|
          c = Campaign.find(ev[1])
          if !data[c.name].nil?
            data[c.name] += 1
          else
            data[c.name] = 1
          end
          total += 1
        end
        data = Hash[data.sort]
      elsif group_by == 'area'
        collection.pluck(:id, :campaign_id).each do |ev|
          Campaign.find(ev[1]).areas_campaigns.each do |ac|
            if ac.events_ids.include?(ev[0])
              if data[ac.area.name].nil?
                data[ac.area.name] = 1
              else
                data[ac.area.name] += 1
              end
              total += 1
            else
              if data[ac.area.name].nil?
                data[ac.area.name] = 0
              end
            end
          end
        end
        data = Hash[data.sort]
      elsif group_by == 'people'
        events_with_userids = Membership.where(memberable_type: 'Event').where('memberable_id in (?)', collection.pluck(:id)).joins("LEFT JOIN company_users ON memberships.company_user_id = company_users.id").pluck(:'memberships.memberable_id', :'company_users.id')

        events_with_userids.each do |ev|
          user = User.find_by(id: ev[1])
          if !user.nil?
            if data[user.name].nil?
              data[user.name] = 1
            else
              data[user.name] += 1
            end
            total += 1
          end
        end
        data = Hash[data.sort]
      else
        statuses = ['approved', 'submitted', 'due', 'late', 'rejected']
        total = 0

        statuses.map{ |s| data[s] = 0 }
        collection.pluck(:id, :aasm_state, :local_end_at, :end_at, :timezone).each do |ev|
          if ev[1] == 'unsent'
            timezone = ev[4]
            if current_company.timezone_support?
              end_at = ev[2]
              today = Timeliness.parse(Time.now.strftime('%Y-%m-%d 00:00:00'), zone: timezone)
              yesterday = Timeliness.parse(Date.yesterday.strftime('%Y-%m-%d 00:00:00'), zone: timezone)
              twodaysago = Timeliness.parse(2.days.ago.strftime('%Y-%m-%d 23:59:59'), zone: timezone)
              end_at = end_at.to_datetime.in_time_zone(timezone)
            else
              end_at = ev[3]
              today = Time.now.in_time_zone(Time.zone)
              yesterday = Date.yesterday.beginning_of_day
              twodaysago = 2.days.ago.end_of_day
            end

            if end_at >= yesterday && end_at <= today
              data['due'] += 1
            end
            if end_at <= twodaysago
              data['late'] += 1
            end
          end

          if !data[ev[1]].nil?
            data[ev[1]] += 1
          else
            data[ev[1]] = 1
          end
          total += 1
        end
      end
      data['total'] = total
      data
    end
end
