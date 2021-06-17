# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :phase_condition do
    phase_id 1
    condition "MyString"
    operator "MyString"
    conditional_phase_id 1
  end
end
