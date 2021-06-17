# == Schema Information
#
# Table name: locations
#
#  id   :integer          not null, primary key
#  path :string(500)
#

# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :location do
    name 'MyString'
    path 'MyString'
  end
end
