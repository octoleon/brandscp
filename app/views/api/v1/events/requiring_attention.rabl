collection @events

attributes :id, :start_date, :start_time, :end_date, :end_time, :status

node :phases do |event|
  event_phases_and_steps_for_api(event)
end

node :event_status do |event|
  if event.unsent?
    if event.late?
      'Late'
    elsif event.in_past?
      'Due'
    else
      'Scheduled'
    end
  else
    event.event_status
  end
end

child(venue: :place) do
  attributes :id, :name, :latitude, :longitude, :formatted_address, :country, :state, :state_name, :city, :route, :street_number, :zipcode
end

node :campaign do |e|
  {id: e.campaign_id, name: e.campaign_name}
end