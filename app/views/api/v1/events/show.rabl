object @event

attributes :id, :start_date, :start_time, :end_date, :end_time, :status, :description

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

node :rejected_info do |event|
  data = {}
  data[:rejected_at] = time_ago_in_words(event.rejected_at || event.updated_at)
  data[:rejected_reason] = event.reject_reason
  data
end

node :have_data do |event|
  event.event_data?
end

if resource.event_data? && resource.event_data.present?
  active_kpis = resource.campaign.active_kpis
  node :data do
    data = {}
    data[:spent_by_impression] = resource.event_data.impressions > 0 ? resource.event_data.spent / resource.event_data.impressions : '0.0' if active_kpis.include?(Kpi.impressions)
    data[:spent_by_interaction] = resource.event_data.interactions > 0 ? resource.event_data.spent / resource.event_data.interactions : '0.0'  if active_kpis.include?(Kpi.interactions)
    data[:spent_by_sample] = resource.event_data.samples > 0 ? resource.event_data.spent / resource.event_data.samples : '0.0'  if active_kpis.include?(Kpi.samples)
    data
  end
end

child(venue: :place) do
  attributes place_id: :id, id: :venue_id, state_code: :state
  attributes :name, :latitude, :longitude, :formatted_address, :country, :state_name, :city, :route, :street_number, :zipcode
end

child :campaign do
  attributes :id, :name, :enabled_modules, :modules
end

node :actions do |event|
  actions = []
  actions.push 'enter post event data' if can?(:view_data, event) && can?(:edit_data, event)
  actions.push 'upload photos' if event.campaign.enabled_modules.include?('photos') && can?(:photos, event) && can?(:create_photo, event)
  actions.push 'conduct surveys' if event.campaign.enabled_modules.include?('surveys') && can?(:surveys, event) && can?(:create_survey, event)
  actions.push 'enter expenses' if event.campaign.enabled_modules.include?('expenses') && can?(:expenses, event) && can?(:create_expense, event)
  actions.push 'gather comments' if event.campaign.enabled_modules.include?('comments') && can?(:comments, event) && can?(:create_comment, event)
  actions
end

node :tasks_late_count do |event|
  event.tasks.late.count
end

node :tasks_due_today_count do |event|
  event.tasks.due_today.count
end