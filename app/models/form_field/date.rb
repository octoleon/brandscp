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

class FormField
  class Date < FormField
    def field_options(result)
      { as: :date_picker,
        label: name,
        field_id: id,
        options: settings,
        required: required,
        input_html: { value: result.value, class: field_classes,
                      step: 'any',
                      required: (self.required? ? 'required' : nil) } }
    end

    def field_classes
      ['field-type-date']
    end

    def format_html(result)
      date = Timeliness.parse(result.value) if result.value
      if date && date.year == ::Time.now.year
        date.strftime('<i>%^a</i> %b %d').html_safe
      else
        date.strftime('<i>%^a</i> %b %d, %Y').html_safe
      end
    rescue
      nil
    end
  end
end
