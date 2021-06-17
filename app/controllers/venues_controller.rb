class VenuesController < FilteredController
  actions :index, :show

  helper_method :data_totals, :venue_activities

  prepend_before_action :create_venue_from_google_api, only: :show

  respond_to :xls, :pdf, only: :index

  custom_actions member: [:select_areas, :add_areas]

  before_action :redirect_to_merged_venue, only: [:show]

  def collection
    @extended_places ||= (super || []).tap do |places|
      ids = places.map { |p| p.place.place_id }
      google_results = load_google_places.reject { |gp| ids.include?(gp.place_id) }
      @collection_count = @collection_count.to_i + google_results.count
      places.concat google_results
    end
    complete_collection_data(@extended_places)
  end

  def select_areas
    @areas = current_company.areas.not_in_venue(resource.place).order('name ASC')
  end

  def add_areas
    @area = current_company.areas.find(params[:area_id])
    resource.place.areas << @area unless resource.place.area_ids.include?(@area.id)
  end

  def delete_area
    @area = current_company.areas.find(params[:area_id])
    resource.place.areas.delete(@area)
  end

  protected

  def collection_to_csv
    CSV.generate do |csv|
      csv << ['VENUE NAME', 'TD LINX CODE', 'ADDRESS', 'CITY', 'STATE', 'SCORE', 'EVENTS COUNT',
              'PROMO HOURS COUNT', 'TOTAL $ SPENT']
      each_collection_item do |venue|
        csv << [venue.name, venue.td_linx_code, venue.formatted_address, venue.city,
                venue.state, venue.score, venue.events_count, venue.events_promo_hours, venue.events_spent]
      end
    end
  end

  def each_collection_item_solr
    (1..@total_pages).each do |page|
      search = resource_class.do_search(@search_params.merge!(page: page))
      complete_collection_data(search.results)
      search.results.each { |result| yield view_context.present(result, params['format']) }
      @_export.update_column(
        :progress, (page * 100 / @total_pages).round) unless @_export.nil?
    end
  end

  def complete_collection_data(results)
    results.each do |place|
      next unless place.is_a?(Venue)
      venue_events = Event.do_search(search_params.slice('company_id',
                                                         'current_company_user',
                                                         'campaign',
                                                         'area',
                                                         'brand',
                                                         'start_date',
                                                         'end_date'
                                                        ).merge(venue: [place.id], without_locations: true, per_page: Event.count)
                                    )
      place.events_count = venue_events.total
      place.events_promo_hours = venue_events.results.collect(&:promo_hours).compact.sum
      place.events_spent = venue_events.results.collect(&:spent).compact.sum
    end
  end

  def permitted_params
    params.permit(venue: [:place_id, :company_id])[:venue]
  end

  def load_google_places
    return [] unless params[:location].present? && params[:q].present?
    (lat, lng) = params[:location].split(',')
    spots = google_places_client.spots(lat, lng, keyword: params[:q], radius: 50_000)
    return [] if spots.empty?
    merged_ids = Place.where.not(merged_with_place_id: nil)
                 .joins('LEFT JOIN places nmp ON nmp.merged_with_place_id IS NULL AND nmp.place_id=places.place_id')
                 .where(place_id: spots.map(&:place_id))
                 .where('nmp.id is null')
                 .pluck(:place_id)
    spots.reject { |s| merged_ids.include?(s.place_id) }
  rescue => e
    puts "Search in google places failed with: #{e.message}"
    puts e.backtrace.inspect
    []
  end

  def create_venue_from_google_api
    return if current_user.nil?
    return if params[:id] =~ /\A[0-9]+\z/
    place = Place.load_by_place_id(params[:id], params[:ref])
    place = Place.find(place.merged_with_place_id) if place.present? && place.merged_with_place_id.present?
    fail ActiveRecord::RecordNotFound unless place
    place.save unless place.persisted?
    venue = current_company.venues.find_or_create_by(place_id: place.id)
    redirect_to venue_path(id: venue.id, return: return_path)
  end

  def google_places_client
    @google_places_client = GooglePlaces::Client.new(GOOGLE_API_KEY)
  end

  def search_params
    @search_params || (super.tap do |p|
      p[:types] = %w(establishment) unless p.key?(:types) && !p[:types].empty?
      # Do not filter by user settigns because we are not filtering google results
      # anyway...
      p[:current_company_user] = nil
      p[:search_address] = true
      if p[:q].present?
        p[:sorting] = :score
        p[:sorting_dir] = :asc
      end

      [:events_count, :promo_hours, :impressions, :interactions, :sampled, :spent, :venue_score].each do |param|
        p[param] ||= {}
        p[param][:min] = nil unless p[:location].present? || p[param][:min].present?
        p[param][:max] = nil if p[param][:max].nil? || p[param][:max].empty?
      end
    end)
  end

  def data_totals
    @data_totals ||= Hash.new.tap do |totals|
      if %w(campaign area brand start_date end_date).any? { |p| params.key? p }
        all_venues = Venue.do_search(search_params.merge(per_page: Venue.count))
        if all_venues.results.present?
          venue_events = Event.do_search(search_params.slice('company_id',
                                                             'current_company_user',
                                                             'campaign',
                                                             'area',
                                                             'brand',
                                                             'start_date',
                                                             'end_date'
                                                            ).merge(venue: all_venues.results.collect(&:id), without_locations: true, per_page: Event.count)
                                        )
          totals['events_count'] = venue_events.total
          totals['promo_hours'] = venue_events.results.collect(&:promo_hours).compact.sum
          totals['spent'] = venue_events.results.collect(&:spent).compact.sum
        else
          totals['events_count'] = 0
          totals['promo_hours'] = 0
          totals['spent'] = 0
        end
      else
        totals['events_count'] = collection_search.stat_response['stats_fields']['events_count_is']['sum'] rescue 0
        totals['promo_hours'] = collection_search.stat_response['stats_fields']['promo_hours_es']['sum'] rescue 0
        totals['spent'] = collection_search.stat_response['stats_fields']['spent_es']['sum'] rescue 0
      end
    end
  end

  def permitted_search_params
    [:location, :q, :page, :sorting, :sorting_dir, :per_page, start_date: [], end_date: [],
     events_count: [:min, :max], promo_hours: [:min, :max], impressions: [:min, :max],
     interactions: [:min, :max], sampled: [:min, :max], spent: [:min, :max],
     venue_score: [:min, :max], price: [], area: [], campaign: [], brand: []]
  end

  def redirect_to_merged_venue
    return if resource.merged_with_place_id.blank?
    redirect_to venue_path(Venue.find_or_create_by(
      company_id: resource.company_id,
      place_id: resource.merged_with_place_id))
  end
end
