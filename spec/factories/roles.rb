# == Schema Information
#
# Table name: roles
#
#  id            :integer          not null, primary key
#  name          :string(255)
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  company_id    :integer
#  active        :boolean          default("true")
#  description   :text
#  is_admin      :boolean          default("false")
#  created_by_id :integer
#  updated_by_id :integer
#

# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :role do
    sequence(:name) { |n| "Role #{n}" }
    description 'Test Role description'
    company_id 1
    is_admin true
    active true

    factory :non_admin_role do
      is_admin false
    end
  end
end
