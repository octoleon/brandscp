# This module defines the do_search method and uses the helper methods
# defined in lib/solr_extensions.rb for filtering by campaign/area/etc

module SolrSearchable
  extend ActiveSupport::Concern

  module ClassMethods
    def build_solr_search(params)
      clazz = self
      Sunspot.new_search(self) do
        self_param_name = (clazz.name == 'CompanyUser' ? :user : clazz.name.underscore.to_sym)
        with :company_id, params[:company_id]
        with_id params.delete(self_param_name) if params[self_param_name]

        #default
        with_campaign params[:campaign] if params[:campaign]
        with_area params[:area], params[:campaign] if params[:area]
        with_place params[:place], params[:without_locations] if params[:place]
        with_location params[:location] if params[:location]
        with_status params[:status] if params[:status]
        with_id params[:id] if params[:id]
        with_activity_type params[:activity_type] if params[:activity_type]
        with_brand params[:brand] if params[:brand]
        with_brand_portfolio params[:brand_portfolio] if params[:brand_portfolio]
        with_venue params[:venue], params[:without_locations] if params[:venue]
        with_event_status params[:event_status] if params[:event_status]
        with_role params[:role] if params[:role]
        with_asset_type params[:asset_type] if params[:asset_type]
        with_media_type params[:media_type] if params[:media_type]
        with_tag params[:tag] if params[:tag]
        with_rating params[:rating] if params[:rating]
        with_event params[:event_id] if params[:event_id]

        between_date_range clazz, params[:start_date], params[:end_date] if params[:start_date] || params[:end_date]

        with_user_teams params

        include_custom_queries # Should be done after all other conditions

        order_by(params[:sorting], params[:sorting_dir] || :asc) if params[:sorting]
        paginate page: (params[:page] || 1), per_page: (params[:per_page] || 30)
      end
    end

    def do_search(params, include_facets = false, includes: nil, &block)
      clazz = self
      search = build_solr_search(params)
      search.build(&block) if block
      search.build(&search_facets) if include_facets && respond_to?(:search_facets, true)
      if params[:current_company_user] && respond_to?(:apply_user_permissions_to_search, true)
        search.build  do
          instance_eval &apply_user_permissions_to_search((params[:search_permission_class] || clazz),
                                           params[:search_permission_subject_id],
                                           params[:search_permission],
                                           params[:current_company_user])
          include_custom_queries
        end
      end
      solr_execute_search(include: includes) do
        search
      end
    end
  end
end
