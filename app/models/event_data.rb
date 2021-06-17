# == Schema Information
#
# Table name: event_data
#
#  id                        :integer          not null, primary key
#  event_id                  :integer
#  impressions               :integer          default("0")
#  interactions              :integer          default("0")
#  samples                   :integer          default("0")
#  gender_female             :decimal(5, 2)    default("0")
#  gender_male               :decimal(5, 2)    default("0")
#  ethnicity_asian           :decimal(5, 2)    default("0")
#  ethnicity_black           :decimal(5, 2)    default("0")
#  ethnicity_hispanic        :decimal(5, 2)    default("0")
#  ethnicity_native_american :decimal(5, 2)    default("0")
#  ethnicity_white           :decimal(5, 2)    default("0")
#  spent                     :decimal(10, 2)   default("0")
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#

class EventData < ActiveRecord::Base
  SEGMENTS_NAMES_MAP = {
    gender:    { 'Male' => 'male', 'Female' => 'female' },
    ethnicity: { 'Asian' => 'asian', 'Black / African American' => 'black',
                 'Hispanic / Latino' => 'hispanic', 'Native American' => 'native_american',
                 'White' => 'white' }
  }

  belongs_to :event
  scope :scoped_by_place_id_and_company_id, ->(places, companies) { joins(:event).where(events: { place_id: places, company_id: companies }) }

  scope :scoped_by_company_id, ->(companies) { joins(:event).where(events: { company_id: companies }) }
  scope :scoped_by_campaign_id, ->(campaigns) { joins(:event).where(events: { campaign_id: campaigns }) }
  scope :for_approved_events, -> { joins(:event).where(events: { aasm_state: 'approved' }) }
  scope :for_active_events, -> { joins(:event).where(events: { active: true }) }
  scope :for_inactive_events, -> { joins(:event).where(events: { active: false }) }

  def update_data
    e = Event.find(event_id)
    self.spent = e.event_expenses.sum(:amount)

    return if Kpi.impressions.nil?

    results = e.results
    [:impressions, :interactions, :samples].each do |kpi_name|
      result = e.result_for_kpi(Kpi.send(kpi_name))
      send("#{kpi_name}=",  result.value.to_i) unless result.nil?
    end

    # For gender and ethnicity
    [:gender, :ethnicity].each do |kpi|
      segments = Kpi.send(kpi).try(:kpis_segments)
      result = e.result_for_kpi(Kpi.send(kpi))
      if result.present? && result.value.present? && segments
        segments.each do |s|
          send("#{kpi}_#{SEGMENTS_NAMES_MAP[kpi][s.text]}=", result.value.try(:[], s.id.to_s).to_f) if result.value.key?(s.id.to_s)
        end
      end
    end
  end
end
