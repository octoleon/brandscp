# == Schema Information
#
# Table name: events
#
#  id                  :integer          not null, primary key
#  campaign_id         :integer
#  company_id          :integer
#  start_at            :datetime
#  end_at              :datetime
#  aasm_state          :string(255)
#  created_by_id       :integer
#  updated_by_id       :integer
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  active              :boolean          default("true")
#  place_id            :integer
#  promo_hours         :decimal(6, 2)    default("0")
#  reject_reason       :text
#  timezone            :string(255)
#  local_start_at      :datetime
#  local_end_at        :datetime
#  description         :text
#  kbmg_event_id       :string(255)
#  rejected_at         :datetime
#  submitted_at        :datetime
#  approved_at         :datetime
#  active_photos_count :integer          default("0")
#  visit_id            :integer
#  results_version     :integer          default("0")
#  areas_ids           :integer          default("{}"), is an Array
#

# Read about factories at https://github.com/thoughtbot/factory_girl
FactoryGirl.define do
  factory :event do
    start_date '01/23/2019'
    start_time '10:00am'
    end_date '01/23/2019'
    end_time '12:00pm'
    aasm_state 'unsent'
    active true
    place_id nil
    campaign_id nil

    ignore do
      results false
      expenses []
      # user_ids nil
      # team_ids nil
    end

    # To keep the associations between campaign and company correct
    after(:build) do |event, _evaluator|
      if event.company.present?
        event.campaign ||= create(:campaign, company: event.company)
      end
      event.campaign ||= create(:campaign)
      event.company ||= event.campaign.company if event.campaign.present?
    end

    before(:create) do |event, evaluator|
      evaluator.expenses.each do |attrs|
        ex = event.event_expenses << build(:event_expense, attrs.merge(event: event))
      end

      if results = evaluator.results
        Kpi.create_global_kpis if Kpi.impressions.nil?
        event.campaign.assign_all_global_kpis if event.form_fields.empty?
        BrandscopiSpecHelpers.set_event_results(event, results, false)
      end
    end
    # after(:create) do |event, evaluator|
    #   event.team_ids = evaluator.team_ids if evaluator.team_ids
    #   event.user_ids = evaluator.user_ids if evaluator.user_ids
    #   event.save if evaluator.team_ids || evaluator.user_ids
    # end

    factory :approved_event do
      start_date Date.yesterday.to_s(:slashes)
      end_date Date.yesterday.to_s(:slashes)
      aasm_state 'approved'
    end

    factory :rejected_event do
      aasm_state 'rejected'
    end

    factory :submitted_event do
      aasm_state 'submitted'
    end

    factory :due_event do
      aasm_state 'unsent'
      start_date { (Time.now - 1.day).to_s(:slashes) }
      start_time { (Time.now - 1.day).strftime('%I:00 %P') }
      end_date { (Time.now - 1.day + 1.hour).to_s(:slashes) }
      end_time { (Time.now - 1.day + 1.hour).strftime('%I:00 %P') }
    end

    factory :late_event do
      aasm_state 'unsent'
      start_date 3.weeks.ago.to_s(:slashes)
      end_date 3.weeks.ago.to_s(:slashes)
    end
  end
end
