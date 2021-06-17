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

class DataExtract < ActiveRecord::Base
  belongs_to :company
  track_who_does_it

  serialize :columns
  serialize :params

  validates :name, presence: true
  validates :source, presence: true

  attr_accessor :filters

  DEFAULT_LIMIT = 30

  attr_accessor :current_user

  scope :active, -> { where(active: true) }

  after_initialize do
    params.serialize_keys! if params.present? && params.respond_to?(:serialize_keys!)
  end

  class << self
    def define_columns(columns)
      @export_columns_definitions = columns
    end

    def exportable_columns
      @exportable_columns ||= columns_definitions.keys.map { |c| [c.to_s,  I18n.t("data_exports.fields.#{model.name.underscore}.#{c}", default: [ :"data_exports.fields.#{c}", :"activerecord.attributes.#{model.name.underscore}.#{c}"] )] }
    end

    def columns_definitions
      @export_columns_definitions || {}
    end

    def model
      @model ||= "::#{name.split('::')[1]}".constantize
    end
  end

  DATA_SOURCES = [
    ['Events', :event], ['Post Event Data (PERs)', :event_data],
    ['Activities', :activity], ['Attendance', :invite],
    ['Comments', :comment], ['Contacts', :contact], ['Expenses', :event_expense],
    ['Tasks', :task], ['Venues', :place], ['Users', :company_user], ['Teams', :team],
    ['Roles', :role], ['Campaigns', :campaign], ['Brands', :brand], ['Activity Types', :activity_type],
    ['Areas', :area], ['Brand Portfolios', :brand_portfolio], ['Date Ranges', :date_range],
    ['Day Parts', :day_part], ['Visits', :brand_ambassadors_visit]
  ]

  after_initialize  do
    self.columns ||= []
    self.columns.delete_if { |c|
      c =~ /\Aff_([0-9]+)(_[0-9]+)?\z/ && form_fields.find_by(id: c.gsub(/ff_([0-9]+)(_[0-9]+)?/, '\1')).nil?
    }
  end

  def columns=(cols)
    self['columns'] = cols.uniq
  end

  def columns_with_names
    columns.map { |c| [c, exportable_columns.find { |ec| ec[0] == c }.try(:[], 1)] }
  end

  def rows(page = 1, format = 'html', per_page: DEFAULT_LIMIT)
    offset = (page - 1) * per_page
    base_scope.order(sort_by).limit(per_page).offset(offset)
              .pluck(*selected_columns_to_sql(format))
  end

  def source
    self.class.name.split('::').last.underscore
  end

  def model
    self.class.model
  end

  def add_joins_to_scope(s)
    s
  end

  def add_filter_conditions_to_scope(s)
    s
  end

  def exportable_columns
    self.class.exportable_columns
  end

  def columns_definitions
    self.class.columns_definitions
  end

  def total_pages
    (total_results.to_f / DEFAULT_LIMIT.to_f).ceil
  end

  def total_results
    @total_results ||= base_scope.count
  end

  def to_hash
    { data_extract: attributes.merge(source: source) }
  end

  def base_scope
    add_filter_conditions_to_scope add_joins_to_scope(model.accessible_by_user(current_user))
  end

  def selected_columns_to_sql(format = 'html')
    cols = columns.map do |col|
      column_definition columns_definitions[col.to_sym]
    end
    format == 'csv' ? cols.unshift("#{source.pluralize}.id").compact : cols.compact
  end

  def sort_by
    col = default_sort_by
    col = columns.first if col.blank? || !columns.include?(col)
    return if col.blank? || !columns_definitions.key?(col.to_sym)
    "#{sort_by_column(col)} #{default_sort_dir || 'ASC'}"
  end

  def sort_by_column(col)
    columns.index(col) + 1
  end

  def column_definition(column)
    column.respond_to?(:call) ? instance_eval(&column) : column
  end

  def filters_scope
    model.name.underscore.pluralize
  end

  def to_partial_path
    'data_extract'
  end

  def filters_include_calendar
    false
  end

  def filtered_by?(keys)
    keys = Array(keys)
    return false if filters.nil? || filters.empty?
    keys.any? { |k| filters.key?(k.to_s)  }
  end

  def activate!
    update_attribute :active, true
  end

  def deactivate!
    update_attribute :active, false
  end
end
