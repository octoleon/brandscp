# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :phase_activity do
    phase_id 1
    activity_type "MyString"
    activity_id 1
    order 1
    display_name "MyString"
    required false
    settings "MyText"
  end
end
