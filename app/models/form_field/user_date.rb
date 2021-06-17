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

class FormField::UserDate < FormField
  def field_options(_result)
    { as: :text }
  end

  def format_html(result)
    result.value.gsub(/\n/, '<br>').html_safe unless result.value.nil?
  end
end
