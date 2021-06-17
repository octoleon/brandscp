# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :phase_activity_condition do
    phase_activity_id 1
    condition 1
    operator 1
    conditional_phase_activity_id 1
  end
end
