# == Schema Information
#
# Table name: form_field_options
#
#  id            :integer          not null, primary key
#  form_field_id :integer
#  name          :string(255)
#  ordering      :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  option_type   :string(255)
#

# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :form_field_option do
    form_field nil
    option_type 'option'
    sequence(:name) { |n| "Form Field Option #{n}" }
    sequence(:ordering) { |n| n }
    factory :form_field_statement do
      option_type 'statement'
    end
  end
end
