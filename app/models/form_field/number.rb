# == Schema Information
#
# Table name: form_fields
#
#  id             :integer          not null, primary key
#  fieldable_id   :integer
#  fieldable_type :string(255)
#  name           :string(255)
#  type           :string(255)
#  settings       :text
#  ordering       :integer
#  required       :boolean
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  kpi_id         :integer
#  multiple       :boolean
#

include ActionView::Helpers::NumberHelper

class FormField::Number < FormField
  def field_options(result)
    {
      as: :string,
      label: name,
      field_id: id,
      options: settings,
      required: required,
      hint: range_message,
      hint_html: {
        id: "hint-#{id}",
        class: 'range-help-block'
      },
      input_html: {
        value: result.value,
        class: field_classes.push('elements-range'),
        data: field_data,
        step: 'any',
        maxlength: max_length,
        required: (self.required? ? 'required' : nil)
      }
    }
  end

  def field_data
    data = {}
    return data unless settings.present?
    data['range-format'] = settings['range_format'] if settings['range_format'].present?
    data['range-min'] = settings['range_min'] if settings['range_min'].present?
    data['range-max'] = settings['range_max'] if settings['range_max'].present?
    data['field-id'] = id
    data
  end

  def max_length
    max_range = settings && settings.key?('range_max') && settings['range_max']
    [max_range, 15].reject(&:blank?).map(&:to_i).min
  end

  def validate_result(result)
    super
    if result.value.present?
      result.errors.add :value, I18n.translate('errors.messages.not_a_number') unless value_is_numeric?(result.value)
    end
  end

  def format_html(result)
    number_with_delimiter(result.value || 0)
  end

  def is_numeric?
    true
  end

  def grouped_results(campaign, event_scope, group_by = nil)
    results = []
    if group_by == 'campaign'
      value = form_field_results.for_event_campaign(campaign).merge(event_scope).map(&:value).compact.reduce { |sum, x| sum.to_f + x.to_f }.to_f || 0
      results << [campaign.name, value]
      results << ['total', value]
    elsif group_by == 'area'
      campaign.areas_campaigns.each do |ac|
        value = form_field_results.for_event_campaign(campaign).merge(event_scope.where(events: { id: ac.events_ids })).map(&:value).compact.reduce { |sum, x| sum.to_f + x.to_f }.to_f || 0
        results << [ac.area.name, value]
      end
      results << ['total', results.map(&:second).reduce(:+) || 0]
    elsif group_by == 'people'
      # Array of pairs [event_id, ff_result_value]
      ids_results = form_field_results.for_event_campaign(campaign).merge(event_scope).all.reject { |r| r.value.to_f.zero? }.map { |r| [r.resultable_id, r.value.to_f] }
      ids_results.each do |result|
        CompanyUser.where(id: Membership.where(memberable_id: result[0]).map(&:company_user_id).uniq).each do |cu|
          results << [cu.name, result[1]]
        end
      end
      results.reject!(&:blank?)
      results << ['total', results.map(&:second).reduce(:+) || 0]
      results = results.reduce(Hash.new(0)) { |h, v| h[v[0]] += v[1]; h }.to_a
    else
      date_field = Company.current.timezone_support? ? :local_end_at : :end_at
      due_date = Company.current.due_event_end_date.utc
      late_date = Company.current.late_event_end_date.utc

      results << ['submitted', form_field_results.for_event_campaign(campaign, 'submitted').merge(event_scope).map(&:value).compact.reduce { |sum, x| sum.to_f + x.to_f }.to_f || 0]
      results << ['approved', form_field_results.for_event_campaign(campaign, 'approved').merge(event_scope).map(&:value).compact.reduce { |sum, x| sum.to_f + x.to_f }.to_f || 0]
      results << ['due', form_field_results.for_event_campaign(campaign, 'unsent').where("#{date_field} < :due AND #{date_field} > :late", due: due_date, late: late_date).merge(event_scope).map(&:value).compact.reduce { |sum, x| sum.to_f + x.to_f }.to_f || 0]
      results << ['late', form_field_results.for_event_campaign(campaign, 'unsent').where("#{date_field} < ?", late_date).merge(event_scope).map(&:value).compact.reduce { |sum, x| sum.to_f + x.to_f }.to_f || 0]
      results << ['rejected', form_field_results.for_event_campaign(campaign, 'rejected').merge(event_scope).map(&:value).compact.reduce { |sum, x| sum.to_f + x.to_f }.to_f || 0]
      results << ['total', results.map(&:second).reduce(:+)]
    end
    results
  end

  def csv_results(campaign, event_scope, hash_result)
    events = form_field_results.for_event_campaign(campaign).merge(event_scope)
    title = kpi.present? ? kpi.name : name
    hash_result[:titles].push(title) unless hash_result[:titles].include? title
    events.each do |event|
      value = event.value.blank? ? '' : event.value
      hash_result[event.resultable_id] << value unless hash_result[event.resultable_id].nil?
    end
    hash_result
  end
end
