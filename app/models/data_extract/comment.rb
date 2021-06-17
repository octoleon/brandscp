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

class DataExtract::Comment < DataExtract
  include DataExtractEventsBase

  define_columns comment: 'comments.content',
                 campaign_name: 'campaigns.name',
                 start_date: proc { "to_char(events.#{date_field_prefix}start_at, 'MM/DD/YYYY')" },
                 start_time: proc { "to_char(events.#{date_field_prefix}start_at, 'HH12:MI AM')" },
                 end_date: proc { "to_char(events.#{date_field_prefix}end_at, 'MM/DD/YYYY')" },
                 end_time: proc { "to_char(events.#{date_field_prefix}end_at, 'HH12:MI AM')" },
                 event_status: 'initcap(events.aasm_state)',
                 street: 'trim(places.street_number || \' \' || places.route)',
                 place_city: 'places.city',
                 place_name: 'places.name',
                 place_state: 'places.state',
                 place_zipcode: 'places.zipcode',
                 created_at: proc { "to_char(comments.created_at, 'MM/DD/YYYY')" },
                 created_by: '(SELECT trim(us.first_name || \' \' || us.last_name) FROM users as us WHERE comments.created_by_id=us.id)',
                 modified_at: proc { "to_char(comments.updated_at, 'MM/DD/YYYY')" },
                 modified_by: '(SELECT trim(us.first_name || \' \' || us.last_name) FROM users as us WHERE comments.updated_by_id=us.id)'

  def add_joins_to_scope(s)
    s = super.joins(:comments)
    s = s.joins('LEFT JOIN users ON comments.created_by_id=users.id') if columns.include?('created_by')
    s
  end

  def filters_scope
    'events'
  end

  def sort_by_column(col)
    case col
    when 'start_date'
      'events.start_at'
    when 'end_date'
      'events.start_at'
    when 'created_at'
      'comments.created_at'
    else
      super
    end
  end

  def filters_include_calendar
    true
  end
end
