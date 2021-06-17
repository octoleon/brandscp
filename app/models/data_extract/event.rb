# == Schema Information
#
# Table name: data_extracts
#
#  id               :integer          not null, primary key
#  type             :string(255)
#  company_id       :integer
#  active           :boolean          default("true")
#  sharing          :string(255)
#  name             :string(255)
#  description      :text
#  columns          :text
#  created_by_id    :integer
#  updated_by_id    :integer
#  created_at       :datetime
#  updated_at       :datetime
#  default_sort_by  :string(255)
#  default_sort_dir :string(255)
#  params           :text
#

class DataExtract::Event < DataExtract
  include DataExtractEventsBase
  define_columns campaign_name: 'campaigns.name',
                 end_date: proc { "to_char(#{date_field_prefix}end_at, 'MM/DD/YYYY')" },
                 end_time: proc { "to_char(#{date_field_prefix}end_at, 'HH12:MI AM')" },
                 start_date: proc { "to_char(#{date_field_prefix}start_at, 'MM/DD/YYYY')" },
                 start_time: proc { "to_char(#{date_field_prefix}start_at, 'HH12:MI AM')" },
                 place_street: 'trim(places.street_number || \' \' || places.route)',
                 place_city: 'places.city',
                 place_name: 'places.name',
                 place_state: 'places.state',
                 place_zipcode: 'places.zipcode',
                 event_team_members: 'array_to_string(ARRAY(SELECT unnest(event_team_members.names) ORDER BY 1), \', \')',
                 event_status: 'initcap(events.aasm_state)',
                 created_at: proc { "to_char(events.created_at, 'MM/DD/YYYY')" },
                 created_by: '(SELECT trim(us.first_name || \' \' || us.last_name) FROM users as us WHERE events.created_by_id=us.id)',
                 modified_at: proc { "to_char(events.updated_at, 'MM/DD/YYYY')" },
                 modified_by: '(SELECT trim(us.first_name || \' \' || us.last_name) FROM users as us WHERE events.updated_by_id=us.id)',
                 approved_at: proc { "to_char(events.approved_at, 'MM/DD/YYYY')" },
                 submitted_at: proc { "to_char(events.submitted_at, 'MM/DD/YYYY')" },
                 status: 'CASE WHEN events.active=\'t\' THEN \'Active\' ELSE \'Inactive\' END'

  def sort_by_column(col)
    case col
    when 'start_date'
      :start_at
    when 'end_date'
      :end_at
    when 'created_at'
      'events.created_at'
    else
      super
    end
  end

  def filters_include_calendar
    true
  end
end
