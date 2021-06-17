module PlacesHelper
  module CreatePlace
    def create_place(attributes, add_new_place)
      attributes[:types] = attributes[:types].downcase.split(/\s*,\s*/) if attributes[:types].present?

      if attributes[:country] && attributes[:state]
        country = Country.new(attributes[:country])
        if country.present? && country.states.key?(attributes[:state])
          attributes[:state] = country.states[attributes[:state]]['name']
        else
          attributes[:state] = nil unless country.present? && country.states.find { |_k, v| v['name'] == attributes[:state] }.present?
        end
      end

      @place = Place.new(attributes)
      reference_value = attributes[:reference]

      if add_new_place
        if set_lat_lon_from_address(@place)
          spot = search_place_in_google_api_by_name(@place)

          # If the place was not found in API, create it
          if spot.nil?
            @place.is_custom_place = true
            @place.save
          else
            reference_value = spot.reference + '||' + spot.place_id
          end
        else
          @place.errors.add(:base, 'The entered address doesn\'t seems to be valid')
        end
      end

      if reference_value && !reference_value.nil? && !reference_value.empty?
        if reference_value =~ /(.*)\|\|(.*)/
          reference, place_id = reference_value.split('||')
          @place = Place.create_with(reference: reference).find_or_create_by(place_id: place_id)
        else
          @place = Place.find(reference_value)
        end

        # There can be spots that doesn't have all address
        # fields in the API, so update it as needed
        @place.city ||= attributes[:city]
        @place.country ||= attributes[:country]
        @place.state ||= attributes[:state]
        @place.street_number ||= attributes[:street_number]
        @place.route ||= attributes[:route]
        @place.zipcode ||= attributes[:zipcode]
        @place.save if @place.changed?
      end

      if @place.persisted?
        has_parent ||= parent.present? rescue false
        parent.update_attributes(place_ids: parent.place_ids + [@place.id]) if has_parent

        # Create a Venue for this place on the current company
        @venue = Venue.find_or_create_by(company_id: current_company.id, place_id: @place.id)
      end

      @place.persisted?
    end

    # Try to find the latitude and logitude based on a physicical address and returns
    # true if found or false if not
    def set_lat_lon_from_address(place)
      address_txt = URI.encode([place.street_number,
                                place.route,
                                place.city,
                                place.state.to_s + ' ' + place.zipcode,
                                place.country].join(', '))

      data = JSON.parse(open("http://maps.googleapis.com/maps/api/geocode/json?address=#{address_txt}&sensor=true").read)

      if data['results'].count > 0
        result = data['results'].find { |r| r['geometry'].present? && r['geometry']['location'].present? }
        if result
          place.lonlat = "POINT(#{result['geometry']['location']['lng']} #{result['geometry']['location']['lat']})"
          true
        else
          false
        end
      else
        address_txt = URI.encode([place.street_number,
                                  place.route,
                                  place.city,
                                  place.country].join(', '))
        data = JSON.parse(open("http://maps.googleapis.com/maps/api/geocode/json?address=#{address_txt}&sensor=true").read)
        if data['results'].count > 0
          result = data['results'].find { |r| r['geometry'].present? && r['geometry']['location'].present? }
          if result
            place.lonlat = "POINT(#{result['geometry']['location']['lng']} #{result['geometry']['location']['lat']})"
            true
          else
            false
          end
        else
          false
        end
      end
    end

    # Search a place in google's API by name in a radius of 1km and returns
    # the spot if found or nil if not
    def search_place_in_google_api_by_name(place)
      api_client.spots(place.latitude, place.longitude, name: place.name, radius: 1000).detect do |spot|
        spot.name.similar(place.name) >= 80
      end
    end

    # Returns a cached API client
    def api_client
      @api_client ||= GooglePlaces::Client.new(GOOGLE_API_KEY)
    end
  end

  def place_website(url)
    link_to url.gsub(/https?:\/\//, '').gsub(/\/$/, ''), url, target: '_blank'
  end

  def venue_score_narrative(venue)
    unless venue.score.nil? || venue.score_impressions.nil?
      if venue.score_impressions <= 33
        if venue.score_cost <= 33
          "#{venue.name} performs poorly relative to similar venues in the area. Not only is it more expensive per impression but it also appears less popular than other venues. Consider conducting fewer events at this venue."
        elsif venue.score_cost <= 66
          "#{venue.name} is about average inpopularity compared to similar venues in the area though is more expensive per impression. Consider looking for lower cost venues if possible."
        else
          "#{venue.name} is a popular venue compared to similar venues in the area with heavy patron traffic but above average costs per impression. If less concerned about budget, this could be attractive."
        end
      elsif venue.score_impressions <= 66
        if venue.score_cost <= 33
          "While the cost per impression for #{venue.name} is comparable to similar venues in the area, it has substantially lower patron traffic. Consider looking for more popular venues if possible."
        elsif venue.score_cost <= 66
          "#{venue.name} is about average compared to similar venues in the area both in terms of popularity and cost per impression. Most venues will fallinto this category."
        else
          "#{venue.name} is a popular venue compared to similar venues in the area with heavy patron traffic and average costs per impression. Consider running more events here when looking to influence more individuals and are within budget."
        end
      else
        if venue.score_cost <= 33
          "While the cost per impression for #{venue.name} is lower than similar venues in the area, patron traffic also seems lower. Consider only running events here on the busiest nights of the week."
        elsif venue.score_cost <= 66
          "#{venue.name} is a good value for the area with low costs per impression and patron traffic comparable to similar venues in the area. Consider running more events here when you are concerned about budget."
        else
          "#{venue.name} is an exceptionally strong venue compared to similar venues in the area.  It is both popular and a relatively low cost. Consider running more events here whenever possible."
        end
      end
    end
  end

  def venue_trend_week_day_narrative(venue)
    stats = resource.overall_graphs_data[:impressions_promo]
    days_names = %w(Monday Tuesday Wednesday Thursday Friday Saturday Sunday)
    days_with_events = stats.map { |x, y| days_names[x] if y > 0 }.compact
    days_count = days_with_events.count
    if days_count > 1
      max = stats.values.max
      best_days = stats.select { |_x, y| y == max }.keys.map { |d| days_names[d] }
      "#{venue.name} has had events on #{days_with_events.to_sentence} and has performed best on #{best_days.to_sentence}. Specifically, #{venue.name} yields more impressions per hour on #{best_days.to_sentence} than on any other day of the week."
    elsif days_count == 1
      "#{venue.name} has only had events on #{days_with_events.first}. Without having events on other days of the week, it is difficult to draw conclusions about what day of the week has shown the best performance at #{venue.name} in the past."
    end
  end

  def place_opening_hours(opening_hours)
    return [] unless opening_hours && opening_hours.key?('periods')
    place_days_opening_hours(opening_hours).values
  end

  def place_days_opening_hours(opening_hours)
    days = %w(Mon Tue Wed Thu Fri Sat Sun)
    return [] unless opening_hours && opening_hours.key?('periods')
    Hash[(0..6).map do |i|
      day = (i == 6 ? 0 : i + 1)
      period = opening_hours['periods'].find { |p| p['open']['day'].to_i == day }
      day_name = days[day]
      desc =
        if period
          if period.key?('open') && period.key?('close')
            "#{day_name} #{Time.parse(period['open']['time'].gsub(/(^[0-9]{2})/, '\1:')).to_s(:time_only)} - #{Time.parse(period['close']['time'].gsub(/(^[0-9]{2})/, '\1:')).to_s(:time_only)}"
          elsif period.key?('open')
            "#{day_name} #{Time.parse(period['open']['time'].gsub(/(^[0-9]{2})/, '\1:')).to_s(:time_only)}"
          end
        else
          "#{day_name} Closed"
        end
      [day_name, desc]
    end]
  end

  def place_opening_hours_formatted(opening_hours)
    full_days = place_days_opening_hours(opening_hours)
    today = full_days[Time.now.strftime('%a')].sub(Time.now.strftime('%a'), 'Today')
    full_days[Time.now.strftime('%a')] = '<b>' + full_days[Time.now.strftime('%a')] + '</b>'
    content_tag(:div, class: 'venues-opening-hours display') do
      content_tag(:span, today) +
      link_to('(Show more)', '#', class: 'show-more-link', data: { toggle: 'collapse', target: '#collapse-venue-hour' })
    end +
    content_tag(:div, id: 'collapse-venue-hour', class: 'venues-opening-hours collapsible collapse') do
      content_tag(:span, full_days.values.join('<br />').html_safe)
    end
  end

  def place_price(price)
    content_tag(:span, price.times.map {|_| '$' }.join, class: 'price-level' ) +
    (5 - price).times.map {|_| '$' }.join.html_safe
  end

  def select_price_level()
    { '$': 1, '$$': 2, '$$$': 3, '$$$$': 4, '$$$$$': 5 }
  end

  def select_days()
    days = { 'Mon': 0, 'Tue': 1, 'Wed': 2, 'Thu': 3, 'Fri': 4, 'Sat': 5, 'Sun': 6 }
  end

  def select_hours()
    hours = { '12:00 am' => '0000', '12:30 am' => '0030' }
    hours = (1..23).inject(hours) do |hash, h|
              ampm = h > 11 ? 'pm' : 'am'
              h24 = h < 10 ? "0#{h}" : h
              hour12 = h > 12 ? h - 12 : h
              h12 = hour12 < 10 ? "0#{hour12}" : hour12
              hash["#{h12}:00 #{ampm}"] = "#{h24}00"
              hash["#{h12}:30 #{ampm}"] = "#{h24}30"
              hash
            end
  end

  private

  def score_calification_for(score)
    if score > 66
      'well relative to'
    elsif score > 33
      'on par with'
    else
      'poorly relative to'
    end
  end

  def avg_impressions_cost_performance_for(venue)
    if stats = avg_stats_for_venue(venue)
      if venue.avg_impressions_hour > stats[:avg_impressions_cost]
        'higher than'
      elsif  venue.avg_impressions == stats[:avg_impressions_cost]
        'on par with'
      else
        'lower than'
      end
    end
  end

  def avg_impressions_hour_performance_for(venue)
    if stats = avg_stats_for_venue(venue)
      if venue.avg_impressions_hour > stats[:avg_impressions_hour]
        'above average'
      elsif  venue.avg_impressions == stats[:avg_impressions_hour]
        'average'
      else
        'below average'
      end
    end
  end

  def avg_stats_for_venue(venue)
    @stats ||= {}
    @stats[venue.id] ||= begin
      search = Venue.solr_search do
        with(:company_id, venue.company_id)
        with(:location).in_radius(venue.latitude, venue.longitude, 5)
        with(:types, venue.types_without_establishment)
        with(:avg_impressions).greater_than(0)

        stat(:avg_impressions, type: 'mean')
        stat(:avg_impressions_hour, type: 'mean')
        stat(:avg_impressions_cost, type: 'mean')
      end
      unless search.stat_response['stats_fields']['avg_impressions_es'].nil?
        {
          avg_impressions: search.stat_response['stats_fields']['avg_impressions_es']['mean'],
          avg_impressions_hour: search.stat_response['stats_fields']['avg_impressions_hour_es']['mean'],
          avg_impressions_cost: search.stat_response['stats_fields']['avg_impressions_cost_es']['mean']
        }
      end
    end
  end
end
