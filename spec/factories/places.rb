# == Schema Information
#
# Table name: places
#
#  id                     :integer          not null, primary key
#  name                   :string(255)
#  reference              :string(400)
#  place_id               :string(200)
#  types_old              :string(255)
#  formatted_address      :string(255)
#  street_number          :string(255)
#  route                  :string(255)
#  zipcode                :string(255)
#  city                   :string(255)
#  state                  :string(255)
#  country                :string(255)
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  administrative_level_1 :string(255)
#  administrative_level_2 :string(255)
#  td_linx_code           :string(255)
#  location_id            :integer
#  is_location            :boolean
#  price_level            :integer
#  phone_number           :string(255)
#  neighborhoods          :string(255)      is an Array
#  lonlat                 :geography({:srid point, 4326
#  td_linx_confidence     :integer
#  merged_with_place_id   :integer
#  types                  :string(255)      is an Array
#

# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :place do
    sequence(:name) { |n| "Place #{n}" }
    place_id nil
    reference nil
    is_custom_place true
    formatted_address '123 My Street'
    lonlat nil
    street_number 11
    route 'Main St.'
    zipcode '12345'
    city 'New York City'
    state 'NY'
    country 'US'
    do_not_connect_to_api true
    types %w(establishment)

    # after(:build) { |u| u.types ||= ['establishment'] }

    factory :city do
      types %w(political locality)
      after(:build) { |p| p.city = p.name }
    end

    factory :state do
      types %w(political administrative_area_level_1)
      after(:build) do |p|
        p.state = p.name
        p.city = nil
      end
    end

    factory :country do
      types %w(political country)
      after(:build) do |p|
        p.state = nil
        p.city = nil
        p.country = Country.all.find { |c| c[0] == 'United States' }[1]
      end
    end

    factory :natural_feature do
      city nil
      state nil
      street_number nil
      route nil
      zipcode nil
      administrative_level_1 nil
      administrative_level_2 nil
      neighborhoods nil
      types %w(natural_feature establishment)
    end
  end
end
