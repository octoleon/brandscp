# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :phase do
    name "MyString"
    description "MyText"
    requires_approval false
    campaign_id 1
    order 1
  end
end
