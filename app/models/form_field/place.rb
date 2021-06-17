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
  class Place < FormField
    def field_options(result)
      {
        as: :location,
        label: name,
        field_id: id,
        options: settings,
        required: required,
        input_html: {
          value: result.value,
          class: field_classes,
          display_value: format_html(result),
          data: field_data,
          required: (self.required? ? 'required' : nil)
        }
      }
    end

    def field_data
      { 'field-id' => id, 'check-valid' => false }
    end

    def format_html(result)
      return if result.value.blank? || result.value == 0
      place = ::Place.where(id: result.value).first
      return place.name_with_location
    end

    def format_csv(result)
      format_html result
    end

    def format_json(result)
      super.merge!(
        if result.nil? || result.value.blank?
          { value: nil }
        else
          { value: result.value,
            display_value: format_html(result) }
        end
      )
    end

    def store_value(value)
      return value if value.to_s.empty? || value.to_s.match(/\A[0-9]*\z/)
      place = ::Place.load_by_place_id(*value.to_s.split('||').reverse!)
      place.save
      place.id
    end
  end
end
