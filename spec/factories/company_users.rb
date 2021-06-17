# == Schema Information
#
# Table name: company_users
#
#  id                      :integer          not null, primary key
#  company_id              :integer
#  user_id                 :integer
#  role_id                 :integer
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  active                  :boolean          default("true")
#  last_activity_at        :datetime
#  notifications_settings  :string(255)      default("{}"), is an Array
#  last_activity_mobile_at :datetime
#  tableau_username        :string(255)
#

# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :company_user do
    company_id 1
    association :user
    role { create(:role, company_id: company_id) }

    ignore do
      permissions []
    end
    after(:create) do |company_user, evaluator|
      evaluator.permissions.each do |p|
        create(:permission, role: company_user.role, action: p[0], subject_class: p[1], mode: 'campaigns')
      end
    end
  end
end
