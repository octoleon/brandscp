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

class FormField::Percentage < FormField::Hashed
  def field_options(result)
    {
      as: :percentage,
      collection: options_for_input,
      label: name,
      field_id: id,
      options: settings,
      required: required,
      label_html: { class: 'control-group-label' },
      segment_html: {
        value: result.value,
        class: field_classes,
        maxlength: 3,
        min: 0,
        step: 'any',
        required: (self.required? ? 'required' : nil)
      }
    }
  end

  def field_classes
    [:percentage, :number, 'segment-field']
  end

  def is_hashed_value?
    true
  end

  def is_optionable?
    true
  end

  def format_json(result)
    super.merge!(
      segments: (options_for_input.map do|s|
                   { id: s[1],
                     text: s[0],
                     value: result.present? && result.value.present? ? result.value[s[1].to_s].to_i : nil,
                     goal: segment_goal(result, s) }
                 end)
    )
  end

  def format_html(result)
    if result.value
      options.map do |option|
        "#{option.name}: #{result.value[option.id.to_s] || 0}%"
      end.join('<br />').html_safe
    end
  end

  def format_text(result)
    return unless result.value
    options.map do |option|
      "#{option.name}: #{result.value[option.id.to_s] || 0}%"
    end.join(', ').html_safe
  end

  def validate_result(result)
    super
    unless result.errors.get(:value) || !result.value.is_a?(Hash)
      total = result.value.values.map(&:to_f).reduce(:+).to_i
      if (required && total != 100) || (!required && total != 100 && total != 0)
        result.errors.add :value, :invalid
      end
    end
  end

  def grouped_results(campaign, event_scope, age = false)
    events = form_field_results.for_event_campaign(campaign).merge(event_scope)
    result = events.map(&:hash_value).compact
    age ? result_for_age(campaign, result) : results_for_percentage_chart_for_hash(result)
  end

  def result_for_age(_campaign, result)
    totals = results_for_hash_values(result)
    total = totals.reduce(0) { |total, (_, value)| total += value.to_i unless value.blank? }
    options_map = Hash[options_for_input.map { |o| [o[1], o[0]] }]
    totals.reduce({}) do |memo, (key, value)|
      memo[options_map[key]] = value.present? && value > 0 ? percent_of(value, total).round(2) : 0
      memo
    end
  end
end
