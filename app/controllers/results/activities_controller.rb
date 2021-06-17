module Results
  class ActivitiesController < FilteredController
    defaults resource_class: ::Activity

    respond_to :xls, :pdf, only: :index
    helper_method :data_totals, :return_path

    private

    def collection_to_csv
      exporter = FormFieldDataExporter.new(current_company_user, search_params, resource_class)
      (CSV.generate do |csv|
        csv << ['CAMPAIGN NAME', 'USER', 'DATE', 'ACTIVITY TYPE', 'AREAS', 'TD LINX CODE',
                'VENUE NAME', 'ADDRESS', 'CITY', 'STATE', 'ZIP', 'COUNTRY', 'ACTIVE STATE', 'CREATED AT',
                'CREATED BY', 'LAST MODIFIED', 'MODIFIED BY'] + exporter.custom_fields_to_export_headers
        each_collection_item do |activity|
          csv << [
            activity.campaign_name, activity.company_user_full_name, activity.date, activity.activity_type_name,
            exporter.area_for_activity(activity), activity.place_td_linx_code, activity.current_place.try(:name), activity.place_address,
            activity.current_place.try(:city), activity.current_place.try(:state), activity.current_place.try(:zipcode), activity.country,
            activity.status, activity.created_at, activity.created_by, activity.last_modified, activity.modified_by] +
            exporter.custom_fields_to_export_values(activity)
        end
      end).encode('WINDOWS-1252', undef: :replace, replace: '')
    end

    def data_totals
      @data_totals ||= Hash.new.tap do |totals|
        totals['activities_count'] = collection_search.total
      end
    end

    def authorize_actions
      authorize! :index_results, Activity
    end

    def return_path
      results_reports_path
    end

    def permitted_search_params
      Event.searchable_params + [activity_type: []]
    end
  end
end
