class TimePickerInput < SimpleForm::Inputs::Base
  def input(_wrapper_options)
    input_html_options[:class] += ['timepicker']
    "#{@builder.text_field(attribute_name, input_html_options)}".html_safe
  end
end
