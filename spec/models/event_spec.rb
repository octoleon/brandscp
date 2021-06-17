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

require 'rails_helper'

describe Event, type: :model do
  it { is_expected.to belong_to(:company) }
  it { is_expected.to belong_to(:campaign) }
  it { is_expected.to have_many(:memberships) }
  it { is_expected.to have_many(:users).through(:memberships) }
  it { is_expected.to have_many(:tasks) }

  it { is_expected.to validate_presence_of(:campaign_id) }
  it { is_expected.to validate_numericality_of(:campaign_id) }
  it { is_expected.to validate_presence_of(:start_at) }
  it { is_expected.to validate_presence_of(:end_at) }

  it { is_expected.to allow_value('12/31/2012').for(:start_date) }
  it { is_expected.not_to allow_value('12/31/12').for(:start_date).with_message('MM/DD/YYYY') }

  describe 'end date validations' do
    before { subject.start_date = '12/31/2012' }
    it { is_expected.to allow_value('12/31/2012').for(:end_date) }
    it { is_expected.not_to allow_value('12/31/12').for(:end_date).with_message('MM/DD/YYYY') }
  end

  describe 'searchable model' do
    it { is_expected.to have_searchable_field(:active) }
    it { is_expected.to have_searchable_field(:start_at) }
    it { is_expected.to have_searchable_field(:start_time) }
    it { is_expected.to have_searchable_field(:end_at) }
    it { is_expected.to have_searchable_field(:local_start_at) }
    it { is_expected.to have_searchable_field(:local_end_at) }
    it { is_expected.to have_searchable_field(:status) }
    it { is_expected.to have_searchable_field(:company_id) }
    it { is_expected.to have_searchable_field(:campaign_id) }
    it { is_expected.to have_searchable_field(:place_id) }
    it { is_expected.to have_searchable_field(:user_ids) }
    it { is_expected.to have_searchable_field(:team_ids) }
    it { is_expected.to have_searchable_field(:team_ids) }
    it { is_expected.to have_searchable_field(:has_event_data) }
    it { is_expected.to have_searchable_field(:has_comments) }
    it { is_expected.to have_searchable_field(:has_surveys) }
    it { is_expected.to have_searchable_field(:promo_hours) }
    it { is_expected.to have_searchable_field(:impressions) }
    it { is_expected.to have_searchable_field(:interactions) }
    it { is_expected.to have_searchable_field(:samples) }
    it { is_expected.to have_searchable_field(:spent) }
    it { is_expected.to have_searchable_field(:gender_female) }
    it { is_expected.to have_searchable_field(:gender_male) }
    it { is_expected.to have_searchable_field(:ethnicity_asian) }
    it { is_expected.to have_searchable_field(:ethnicity_black) }
    it { is_expected.to have_searchable_field(:ethnicity_hispanic) }
    it { is_expected.to have_searchable_field(:ethnicity_native_american) }
    it { is_expected.to have_searchable_field(:ethnicity_white) }
    it { is_expected.to have_searchable_field(:expenses_with_receipts) }
  end

  describe 'populate event info on create' do
    it 'should create new events with its areas ids' do
      company = create(:company)
      campaign = create(:campaign, company: company)

      area_la = create(:area, company: company)
      area_sf = create(:area, company: company)

      campaign.areas << [area_la, area_sf]

      area_la.places << create(:place, country: 'US', state: 'California', city: 'Los Angeles', types: ['locality'])
      area_sf.places << create(:place, country: 'US', state: 'California', city: 'San Francisco', types: ['locality'])

      event_la = create(:event, campaign: campaign,
                                place: create(:place, country: 'US',
                                                      state: 'California', city: 'Los Angeles'))

      event_sf = create(:event, campaign: campaign,
                                place: create(:place, country: 'US',
                                                      state: 'California', city: 'San Francisco'))

      expect(event_la.areas_ids).to eq([area_la.id])
      expect(event_sf.areas_ids).to eq([area_sf.id])
    end
  end

  describe 'event results validations' do
    it 'should not allow submitting the event if the results are not valid' do
      campaign = create(:campaign)
      field = create(:form_field_number, fieldable: campaign, kpi: create(:kpi, company_id: 1), required: true)
      field = FormField.find(field.id)
      event = create(:event, campaign: campaign)

      expect do
        event.submit
      end.to raise_exception(AASM::InvalidTransition)

      event.results_for([field]).each { |r| r.value = 100 }
      event.save
      expect(event.submit).to be_truthy
    end
  end

  describe 'end_after_start validation' do
    subject { described_class.new(start_at: Time.zone.local(2016, 1, 20, 12, 5, 0)) }

    it { is_expected.not_to allow_value(Time.zone.local(2016, 1, 20, 12, 0, 0)).for(:end_at).with_message('must be after') }
    it { is_expected.to allow_value(Time.zone.local(2016, 1, 20, 12, 5, 0)).for(:end_at) }
    it { is_expected.to allow_value(Time.zone.local(2016, 1, 20, 12, 10, 0)).for(:end_at) }
  end

  describe 'between_visit_date_range validation' do
    let(:company) { create(:company) }
    let(:visit) do
      create(:brand_ambassadors_visit, company: company,
                                       start_date: '02/01/2016', end_date: '02/02/2016',
                                       company_user: create(:company_user, company: company))
    end

    subject do
      described_class.new(start_at: Time.zone.local(2016, 2, 1, 11, 5, 0),
                          end_at: Time.zone.local(2016, 2, 1, 12, 5, 0),
                          visit_id: visit.id)
    end

    it do
      is_expected.not_to allow_value(Time.zone.local(2016, 1, 31, 12, 0, 0).to_s(:slashes))
        .for(:start_date).with_message('should be after 01/31/2016')
    end

    it do
      is_expected.not_to allow_value(Time.zone.local(2016, 2, 3, 12, 5, 0).to_s(:slashes))
        .for(:end_date).with_message('should be before 02/03/2016')
    end

    it do
      is_expected.to allow_value(Time.zone.local(2016, 2, 1, 12, 5, 0).to_s(:slashes))
        .for(:start_date)
    end

    it do
      is_expected.to allow_value(Time.zone.local(2016, 2, 2, 12, 5, 0).to_s(:slashes))
        .for(:end_date)
    end
  end

  describe 'between_visit_date_range: visit no present' do
    it 'visit no present' do
      event = described_class.new(start_at: Time.zone.local(2016, 2, 1, 11, 5, 0),
                                  end_at: Time.zone.local(2016, 2, 1, 12, 5, 0))

      expect(event.instance_eval { between_visit_date_range }).to eql nil
    end
  end

  describe 'reset_verification' do
    let(:user) { create(:user) }

    it 'should set phone_number_verified to false when the number is changed' do
      user.update_column(:phone_number_verified, true)
      user.reload
      expect(user.phone_number_verified).to be_truthy

      user.phone_number = '123213211'
      user.save
      expect(user.phone_number_verified).to be_falsey
    end

    it 'should set phone_number_verification to nil when the number is changed' do
      user.update_column(:phone_number_verification, '122322')
      user.reload
      expect(user.phone_number_verification).to eql '122322'

      user.phone_number = '123213211'
      user.save
      expect(user.phone_number_verification).to be_nil
    end

    it 'should set phone_number_verified true if a valid code is given' do
      user.update_column(:phone_number_verification, '122322')
      user.update_column(:phone_number_verified, false)
      user.reload
      expect(user.phone_number_verification).to eql '122322'
      expect(user.phone_number_verified).to be_falsey

      user.verification_code = '122322'
      expect(user.save).to be_truthy
      expect(user.phone_number_verified).to be_truthy
    end
  end

  describe 'states' do
    let(:event) { create(:event) }

    describe ':unsent' do
      it 'should be an initial state' do
        expect(event).to be_unsent
      end

      it 'should change to :submitted on :unsent or :rejected' do
        event.submit
        expect(event.submitted_at).to be_present
        expect(event).to be_submitted
      end

      it 'should change to :approved on :submitted' do
        event.submit
        expect(event.submitted_at).to be_present
        event.approve
        expect(event.approved_at).to be_present
        expect(event).to be_approved
      end

      it 'should change to :submitted on :approved' do
        event.submit
        expect(event.submitted_at).to be_present
        event.approve
        expect(event.approved_at).to be_present
        event.unapprove
        expect(event.approved_at).to be_nil
        expect(event).to be_submitted
      end

      it 'should change to :rejected on :submitted' do
        event.submit
        expect(event.submitted_at).to be_present
        event.reject
        expect(event.rejected_at).to be_present
        expect(event).to be_rejected
      end
    end
  end

  describe '#create_notifications' do
    let(:company) { create(:company, event_alerts_policy: Notification::EVENT_ALERT_POLICY_ALL) }

    it 'should queue EventNotifierWorker worker' do
      expect(EventNotifierWorker).to receive(:perform_async)
      create(:event, company: company)
    end

    it "should NOT queue EventNotifierWorker if the company's setting is set to team only" do
      company.settings = { event_alerts_policy: Notification::EVENT_ALERT_POLICY_TEAM }
      company.save
      expect(EventNotifierWorker).to_not receive(:perform_async)
      create(:event, company: company)
    end

    it "should NOT queue EventNotifierWorker if the company's setting is not set" do
      company.settings = {}
      company.save
      expect(EventNotifierWorker).to_not receive(:perform_async)
      create(:event, company: company)
    end
  end

  describe '#accessible_by' do
    let!(:event) { create(:event, campaign: campaign, place: place) }

    let(:company) { create(:company) }
    let(:campaign) { create(:campaign, company: company) }
    let(:place) { create(:place, country: 'US', state: 'California', city: 'Los Angeles') }
    let(:area) { create(:area, company: company) }
    let(:company_user) { create(:company_user, company: company, role: create(:role, is_admin: false, company: company)) }

    it "should return empty if the user doesn't have campaigns nor places" do
      expect(described_class.accessible_by_user(company_user)).to be_empty
    end

    it 'should return empty if the user have access to the campaign but not the place' do
      company_user.campaigns << campaign
      expect(described_class.accessible_by_user(company_user)).to be_empty
    end

    it 'should return the event if the user have the place directly assigned to the user' do
      company_user.campaigns << campaign
      company_user.places << place
      expect(described_class.accessible_by_user(company_user)).to match_array([event])
    end

    it 'should return the event if the user have access to an area that includes the place' do
      company_user.campaigns << campaign
      area.places << place
      company_user.areas << area
      expect(described_class.accessible_by_user(company_user)).to match_array([event])
    end

    it 'should return the event if the user has access to the city' do
      company_user.campaigns << campaign
      company_user.places << create(:place, country: 'US', state: 'California',
                                            city: 'Los Angeles', types: ['locality'])
      expect(described_class.accessible_by_user(company_user)).to match_array([event])
    end
  end

  describe 'with_user_in_team' do
    let(:campaign) { create(:campaign) }
    let(:user) { create(:company_user, company: campaign.company) }
    it 'should return empty if the user is not assiged to any event' do
      expect(described_class.with_user_in_team(user)).to be_empty
    end

    it 'should return all the events where a user is assigned as part of the event team' do
      events = create_list(:event, 3, campaign: campaign)
      events.each { |e| e.users << user }
      create(:event, campaign: campaign)

      expect(described_class.with_user_in_team(user)).to match_array(events)
    end

    it 'should return all the events where a user is part of a team that is assigned to the event' do
      events = create_list(:event, 3, campaign: campaign)
      team = create(:team, company: campaign.company)
      team.users << user
      events.each { |e| e.teams << team }
      create(:event, campaign: campaign)

      expect(described_class.with_user_in_team(user)).to match_array(events)
    end
  end

  describe '#in_campaign_area' do
    let(:company) { create(:company) }
    let(:campaign) { create(:campaign, company: company) }

    it 'should include only events within the given areas' do
      event_la = create(:event, campaign: campaign,
                                place: create(:place, country: 'US', state: 'California', city: 'Los Angeles'))

      event_sf = create(:event, campaign: campaign,
                                place: create(:place, country: 'US', state: 'California', city: 'San Francisco'))

      area_la = create(:area, company: company)
      area_sf = create(:area, company: company)

      area_la.places << create(:place, country: 'US', state: 'California', city: 'Los Angeles', types: ['locality'])
      area_sf.places << create(:place, country: 'US', state: 'California', city: 'San Francisco', types: ['locality'])

      area_campaign_la = create(:areas_campaign, area: area_la, campaign: campaign)
      area_campaign_sf = create(:areas_campaign, area: area_sf, campaign: campaign)

      expect(described_class.in_campaign_area(area_campaign_la)).to match_array [event_la]
      expect(described_class.in_campaign_area(area_campaign_sf)).to match_array [event_sf]
    end

    it 'should include events that are scheduled on places that are part of the areas' do
      place_la = create(:place, country: 'US', state: 'California', city: 'Los Angeles')
      event_la = create(:event, campaign: campaign, place: place_la)

      place_sf = create(:place, country: 'US', state: 'California', city: 'San Francisco')
      event_sf = create(:event, campaign: campaign, place: place_sf)

      area_la = create(:area, company: company)
      area_sf = create(:area, company: company)

      area_la.places << place_la
      area_sf.places << place_sf

      area_campaign_la = create(:areas_campaign, area: area_la, campaign: campaign)
      area_campaign_sf = create(:areas_campaign, area: area_sf, campaign: campaign)

      expect(described_class.in_campaign_area(area_campaign_la)).to match_array [event_la]
      expect(described_class.in_campaign_area(area_campaign_sf)).to match_array [event_sf]
    end

    it 'should exclude events that are scheduled on places that were excluded from the campaign' do
      place_la = create(:place, country: 'US', state: 'California', city: 'Los Angeles')
      create(:event, campaign: campaign, place: place_la)

      place_sf = create(:place, country: 'US', state: 'California', city: 'San Francisco')
      event_sf = create(:event, campaign: campaign, place: place_sf)

      area_la = create(:area, company: company)
      area_sf = create(:area, company: company)

      area_la.places << place_la
      area_sf.places << place_sf

      area_campaign_la = create(:areas_campaign, area: area_la, campaign: campaign, exclusions: [place_la.id])
      area_campaign_sf = create(:areas_campaign, area: area_sf, campaign: campaign)
      expect(described_class.in_campaign_area(area_campaign_la)).to be_empty
      expect(described_class.in_campaign_area(area_campaign_sf)).to match_array [event_sf]
    end

    it 'should exclude events that are scheduled on places inside an excluded city' do
      place_la = create(:place, country: 'US', state: 'California', city: 'Los Angeles')
      event_la = create(:event, campaign: campaign, place: place_la)

      city_la = create(:city, name: 'Los Angeles', country: 'US', state: 'California')
      area_la = create(:area, company: company)

      area_la.places << city_la

      area_campaign_la = create(:areas_campaign, area: area_la, campaign: campaign)
      expect(described_class.in_campaign_area(area_campaign_la)).to match_array [event_la]

      area_campaign_la.exclusions = [city_la.id]
      expect(described_class.in_campaign_area(area_campaign_la)).to be_empty
    end

    it 'should includes events that are scheduled on places inside an included city' do
      campaign2 = create(:campaign, company: company)
      place_la = create(:place, country: 'US', state: 'California', city: 'Los Angeles')
      event_la = create(:event, campaign: campaign, place: place_la)

      city_la = create(:city, name: 'Los Angeles', country: 'US', state: 'California')
      area_la = create(:area, company: company)

      area_campaign_la = create(:areas_campaign, area: area_la, campaign: campaign)
      area_campaign2_la = create(:areas_campaign, area: area_la, campaign: campaign2)
      expect(described_class.in_campaign_area(area_campaign_la)).to be_empty
      expect(described_class.in_campaign_area(area_campaign2_la)).to be_empty

      area_campaign_la.update_attribute :inclusions, [city_la.id]
      expect(described_class.in_campaign_area(area_campaign_la)).to match_array [event_la]
      expect(described_class.in_campaign_area(area_campaign2_la)).to be_empty
    end
  end

  describe '#in_campaign_areas' do
    let(:company) { create(:company) }
    let(:campaign) { create(:campaign, company: company) }

    it 'should include only events within the given areas' do
      event_la = create(:event, campaign: campaign,
                                place: create(:place, country: 'US', state: 'California', city: 'Los Angeles'))

      event_sf = create(:event, campaign: campaign,
                                place: create(:place, country: 'US', state: 'California', city: 'San Francisco'))

      area_la = create(:area, company: company)
      area_sf = create(:area, company: company)

      campaign.areas << [area_la, area_sf]

      area_la.places << create(:place, country: 'US', state: 'California', city: 'Los Angeles', types: ['locality'])
      area_sf.places << create(:place, country: 'US', state: 'California', city: 'San Francisco', types: ['locality'])

      create(:areas_campaign, area: area_la, campaign: campaign)
      create(:areas_campaign, area: area_sf, campaign: campaign)

      expect(described_class.in_campaign_areas(campaign, [area_la])).to match_array [event_la]
      expect(described_class.in_campaign_areas(campaign, [area_sf])).to match_array [event_sf]
      expect(described_class.in_campaign_areas(campaign, [area_la, area_sf])).to match_array [event_la, event_sf]
    end

    it 'should include events that are scheduled on places that are part of the areas' do
      place_la = create(:place, country: 'US', state: 'California', city: 'Los Angeles')
      event_la = create(:event, campaign: campaign, place: place_la)

      place_sf = create(:place, country: 'US', state: 'California', city: 'San Francisco')
      event_sf = create(:event, campaign: campaign, place: place_sf)

      area_la = create(:area, company: company)
      area_sf = create(:area, company: company)

      area_la.places << place_la
      area_sf.places << place_sf

      campaign.areas << [area_la, area_sf]

      # Create another campaign just to test
      campaign2 = create(:campaign, company: company)
      campaign2.areas << [area_la, area_sf]

      expect(described_class.in_campaign_areas(campaign, [area_la])).to match_array [event_la]
      expect(described_class.in_campaign_areas(campaign, [area_sf])).to match_array [event_sf]
      expect(described_class.in_campaign_areas(campaign, [area_la, area_sf])).to match_array [event_la, event_sf]
    end

    it 'should exclude events that are scheduled on places that were excluded from the campaign' do
      place_la = create(:place, country: 'US', state: 'California', city: 'Los Angeles')
      event_la = create(:event, campaign: campaign, place: place_la)

      place_sf = create(:place, country: 'US', state: 'California', city: 'San Francisco')
      event_sf = create(:event, campaign: campaign, place: place_sf)

      area_la = create(:area, company: company)
      area_sf = create(:area, company: company)

      area_la.places << place_la
      area_sf.places << place_sf

      area_campaign_la = create(:areas_campaign, area: area_la, campaign: campaign, exclusions: [place_la.id])
      area_campaign_sf = create(:areas_campaign, area: area_sf, campaign: campaign)

      expect(described_class.in_campaign_areas(campaign, [area_la])).to be_empty
      expect(described_class.in_campaign_areas(campaign, [area_sf])).to match_array [event_sf]
    end

    it 'should exclude events that are scheduled on places inside an excluded city' do
      place_la = create(:place, country: 'US', state: 'California', city: 'Los Angeles')
      event_la = create(:event, campaign: campaign, place: place_la)

      city_la = create(:city, name: 'Los Angeles', country: 'US', state: 'California')
      area_la = create(:area, company: company)

      area_la.places << city_la

      area_campaign_la = create(:areas_campaign, area: area_la, campaign: campaign)
      expect(described_class.in_campaign_areas(campaign, [area_la])).to match_array [event_la]

      area_campaign_la.update_attribute :exclusions, [city_la.id]
      expect(described_class.in_campaign_areas(campaign, [area_la])).to be_empty
    end

    it 'should includes events that are scheduled on places inside an included city' do
      campaign2 = create(:campaign, company: company)
      place_la = create(:place, country: 'US', state: 'California', city: 'Los Angeles')
      place_sf = create(:place, country: 'US', state: 'California', city: 'San Francisco')
      event_la = create(:event, campaign: campaign, place: place_la)
      event_sf = create(:event, campaign: campaign, place: place_sf)

      city_la = create(:city, name: 'Los Angeles', country: 'US', state: 'California')
      city_sf = create(:city, name: 'San Francisco', country: 'US', state: 'California')
      area_la = create(:area, company: company)
      area_sf = create(:area, company: company)
      area_sf.places << city_sf

      area_campaign_la = create(:areas_campaign, area: area_la, campaign: campaign)
      area_campaign_sf = create(:areas_campaign, area: area_sf, campaign: campaign)
      create(:areas_campaign, area: area_la, campaign: campaign2)
      expect(described_class.in_campaign_areas(campaign, [area_la])).to be_empty
      expect(described_class.in_campaign_areas(campaign2, [area_la])).to be_empty

      area_campaign_la.update_attribute :inclusions, [city_la.id]
      expect(described_class.in_campaign_areas(campaign, [area_la])).to match_array [event_la]
      expect(described_class.in_campaign_areas(campaign2, [area_la])).to be_empty

      expect(described_class.in_campaign_areas(campaign, [area_la, area_sf])).to match_array [event_la, event_sf]
    end
  end

  describe '#in_areas' do
    let(:company) { create(:company) }
    let(:campaign) { create(:campaign, company: company) }

    it 'should include only events within the given areas' do
      event_la = create(:event, campaign: campaign,
                                place: create(:place, country: 'US',
                                                      state: 'California', city: 'Los Angeles'))

      event_sf = create(:event, campaign: campaign,
                                place: create(:place, country: 'US',
                                                      state: 'California', city: 'San Francisco'))

      area_la = create(:area, company: company)
      area_sf = create(:area, company: company)

      campaign.areas << [area_la, area_sf]

      area_la.places << create(:place, country: 'US', state: 'California', city: 'Los Angeles', types: ['locality'])
      area_sf.places << create(:place, country: 'US', state: 'California', city: 'San Francisco', types: ['locality'])

      expect(described_class.in_areas([area_la])).to match_array [event_la]
      expect(described_class.in_areas([area_sf])).to match_array [event_sf]
      expect(described_class.in_areas([area_la, area_sf])).to match_array [event_la, event_sf]
    end

    it 'should include events that are scheduled on places that are part of the areas' do
      place_la = create(:place, country: 'US', state: 'California', city: 'Los Angeles', types: ['locality'])
      event_la = create(:event, campaign: campaign, place: place_la)

      place_sf = create(:place, country: 'US', state: 'California', city: 'San Francisco', types: ['locality'])
      event_sf = create(:event, campaign: campaign, place: place_sf)

      area_la = create(:area, company: company)
      area_sf = create(:area, company: company)

      area_la.places << place_la
      area_sf.places << place_sf

      # Create another campaign just to test
      campaign2 = create(:campaign, company: company)

      expect(described_class.in_areas([area_la])).to match_array [event_la]
      expect(described_class.in_areas([area_sf])).to match_array [event_sf]
      expect(described_class.in_areas([area_la, area_sf])).to match_array [event_la, event_sf]
    end
  end

  describe '#in_places' do
    let(:company) { create(:company) }
    let(:campaign) { create(:campaign, company: company) }

    it 'should include events that are scheduled on the given places' do
      place_la = create(:place, country: 'US', state: 'California', city: 'Los Angeles')
      event_la = create(:event, campaign: campaign, place: place_la)

      place_sf = create(:place, country: 'US', state: 'California', city: 'San Francisco')
      event_sf = create(:event, campaign: campaign, place: place_sf)

      expect(described_class.in_places([place_la])).to match_array [event_la]
      expect(described_class.in_places([place_sf])).to match_array [event_sf]
    end

    it 'should include events that are scheduled within the given scope if the place is a locality' do
      los_angeles = create(:place, country: 'US', state: 'California', city: 'Los Angeles', types: ['locality'])
      event_la = create(:event, campaign: campaign,
                                place: create(:place, country: 'US', state: 'California', city: 'Los Angeles'))

      san_francisco = create(:place, country: 'US', state: 'California', city: 'San Francisco', types: ['locality'])
      event_sf = create(:event, campaign: campaign,
                                place: create(:place, country: 'US', state: 'California', city: 'San Francisco'))

      expect(described_class.in_places([los_angeles])).to match_array [event_la]
      expect(described_class.in_places([san_francisco])).to match_array [event_sf]
      expect(described_class.in_places([los_angeles, san_francisco])).to match_array [event_la, event_sf]
    end
  end

  describe '#start_at attribute' do
    it 'should be correctly set when assigning valid start_date and start_time' do
      event = described_class.new
      event.start_date = '01/20/2012'
      event.start_time = '12:05pm'
      event.valid?
      expect(event.start_at).to eq(Time.zone.local(2012, 1, 20, 12, 5, 0))
    end

    it 'should be nil if no start_date and start_time are provided' do
      event = described_class.new
      event.valid?
      expect(event.start_at).to be_nil
    end

    it 'should have only the date if no start_time provided' do
      event = described_class.new
      event.start_date = '01/20/2012'
      event.start_time = nil
      event.valid?
      expect(event.start_at).to eq(Time.zone.local(2012, 1, 20, 0, 0, 0))
    end
  end

  describe '#end_at attribute' do
    it 'should be correcly set when assigning valid end_date and end_time' do
      event = described_class.new
      event.end_date = '01/20/2012'
      event.end_time = '12:05pm'
      event.valid?
      expect(event.end_at).to eq(Time.zone.local(2012, 1, 20, 12, 5, 0))
    end

    it 'should be nil if no end_date and end_time are provided' do
      event = described_class.new
      event.valid?
      expect(event.end_at).to be_nil
    end

    it 'should have only the date if no end_time provided' do
      event = described_class.new
      event.end_date = '01/20/2012'
      event.end_time = nil
      event.valid?
      expect(event.end_at).to eq(Time.zone.local(2012, 1, 20, 0, 0, 0))
    end
  end

  describe 'campaign association' do
    let(:campaign) { create(:campaign) }

    it "should update campaign's first_event_id and first_event_at attributes" do
      expect(campaign.update_attributes(first_event_id: 999, first_event_at: '2013-02-01 12:00:00')).to be_truthy
      event = create(:event, campaign: campaign, company: campaign.company, start_date: '01/01/2013', start_time: '01:00 AM', end_date:  '01/01/2013', end_time: '05:00 AM')
      campaign.reload
      expect(campaign.first_event_id).to eq(event.id)
      expect(campaign.first_event_at).to eq(Time.zone.parse('2013-01-01 01:00:00'))
    end

    it "should update campaign's first_event_id and first_event_at attributes" do
      expect(campaign.update_attributes(last_event_id: 999, last_event_at: '2013-01-01 12:00:00')).to be_truthy
      event = create(:event, campaign: campaign, company: campaign.company, start_date: '02/01/2013', start_time: '01:00 AM', end_date:  '02/01/2013', end_time: '05:00 AM')
      campaign.reload
      expect(campaign.last_event_id).to eq(event.id)
      expect(campaign.last_event_at).to eq(Time.zone.parse('2013-02-01 01:00:00'))
    end
  end

  describe '#kpi_goals' do
    let(:campaign) { create(:campaign) }
    let(:event) { create(:event, campaign: campaign, company: campaign.company) }

    it 'should not fail if there are not goals nor KPIs for the campaign' do
      expect(event.kpi_goals).to eq({})
    end

    it 'should not fail if there are KPIs associated to the campaign but without goals' do
      Kpi.create_global_kpis
      campaign.assign_all_global_kpis
      expect(event.kpi_goals).to eq({})
    end

    it 'should not fail if the goal values are nil' do
      Kpi.create_global_kpis
      campaign.assign_all_global_kpis
      goals = campaign.goals.for_kpis([Kpi.impressions])
      goals.each { |g| g.value = nil; g.save }
      expect(event.kpi_goals).to eq({})
    end

    it 'returns the correct value for the goal' do
      Kpi.create_global_kpis
      campaign.assign_all_global_kpis
      goals = campaign.goals.for_kpis([Kpi.impressions])
      goals.each { |g| g.value = 100; g.save }
      expect(event.kpi_goals).to eq(Kpi.impressions.id => 100)
    end

    it 'returns the correctly divide the goal between the number of events' do
      Kpi.create_global_kpis
      campaign.assign_all_global_kpis
      # Create another event for the campaign
      create(:event, campaign: campaign, company: campaign.company)
      goals = campaign.goals.for_kpis([Kpi.impressions])
      goals.each { |g| g.value = 100; g.save }
      expect(event.kpi_goals).to eq(Kpi.impressions.id => 50)
    end
  end

  describe 'before_save #set_promo_hours' do
    it 'correctly calculates the number of promo hours before saving the event' do
      event = build(:event,  start_date: '05/21/2020', start_time: '12:00pm', end_date: '05/21/2020', end_time: '05:00pm')
      event.promo_hours = nil
      expect(event.save).to be_truthy
      expect(event.reload.promo_hours).to eq(5)
    end
    it 'accepts promo_hours hours with decimals' do
      event = build(:event, start_date: '05/21/2020', start_time: '12:00pm', end_date: '05/21/2020', end_time: '03:15pm')
      event.promo_hours = nil
      expect(event.save).to be_truthy
      expect(event.reload.promo_hours).to eq(3.25)
    end
  end

  describe 'in_past?' do
    after do
      Timecop.return
    end
    it 'should return true if the event is scheduled to happen in the past' do
      Timecop.freeze(Time.zone.local(2013, 07, 26, 12, 13)) do
        event = build(:event)
        event.end_at = Time.zone.local(2013, 07, 26, 12, 00)
        expect(event.in_past?).to be_truthy

        event.end_at = Time.zone.local(2013, 07, 26, 12, 12)
        expect(event.in_past?).to be_truthy

        event.end_at = Time.zone.local(2013, 07, 26, 12, 15)
        expect(event.in_past?).to be_falsey
      end
    end

    it 'should return true if the event is scheduled to happen in the future' do
      Timecop.freeze(Time.zone.local(2013, 07, 26, 12, 13)) do
        event = build(:event)
        event.start_at = Time.zone.local(2013, 07, 26, 12, 00)
        expect(event.in_future?).to be_falsey

        event.start_at = Time.zone.local(2013, 07, 26, 12, 12)
        expect(event.in_future?).to be_falsey

        event.start_at = Time.zone.local(2013, 07, 26, 12, 15)
        expect(event.in_future?).to be_truthy

        event.start_at = Time.zone.local(2014, 07, 26, 12, 15)
        expect(event.in_future?).to be_truthy
      end
    end
  end

  describe 'late?' do
    after do
      Timecop.return
    end
    it 'should return true if the event is scheduled to happen in more than to days go' do
      Timecop.freeze(Time.zone.local(2013, 07, 26, 12, 13)) do
        event = create(:event, start_date: '07/23/2013', end_date: '07/23/2013', start_time: '10:00 am', end_time: '2:00 pm')
        expect(event.late?).to be_truthy

        event = create(:event, start_date: '01/23/2013', end_date: '01/23/2013', start_time: '10:00 am', end_time: '2:00 pm')
        expect(event.late?).to be_truthy
      end
    end
    it 'should return false if the event is end_date is less than two days ago' do
      Timecop.freeze(Time.zone.local(2013, 07, 26, 12, 13)) do
        event = create(:event, start_date: '07/23/2013', end_date: '07/25/2013', start_time: '10:00 am', end_time: '2:00 pm')
        expect(event.late?).to be_falsey
      end
    end
  end

  describe 'happens_today?' do
    after do
      Timecop.return
    end
    it 'should return true if the current day is between the start and end dates of the event' do
      Timecop.freeze(Time.zone.local(2013, 07, 26, 12, 13)) do
        event = create(:event, start_date: '07/26/2013', end_date: '07/26/2013', start_time: '10:00 am', end_time: '2:00 pm')
        expect(event.happens_today?).to be_truthy

        event = create(:event, start_date: '07/26/2013', end_date: '07/28/2013', start_time: '10:00 am', end_time: '2:00 pm')
        expect(event.happens_today?).to be_truthy

        event = create(:event, start_date: '07/24/2013', end_date: '07/26/2013', start_time: '10:00 am', end_time: '2:00 pm')
        expect(event.happens_today?).to be_truthy

        event = create(:event, start_date: '07/23/2013', end_date: '07/28/2013', start_time: '10:00 am', end_time: '2:00 pm')
        expect(event.happens_today?).to be_truthy
      end
    end

    it 'should return true if the current day is NOT between the start and end dates of the event' do
      Timecop.freeze(Time.zone.local(2013, 07, 26, 12, 13)) do
        event = create(:event, start_date: '07/27/2013', end_date: '07/28/2013', start_time: '10:00 am', end_time: '2:00 pm')
        expect(event.happens_today?).to be_falsey

        event = create(:event, start_date: '07/24/2013', end_date: '07/25/2013', start_time: '10:00 am', end_time: '2:00 pm')
        expect(event.happens_today?).to be_falsey
      end
    end
  end

  describe 'was_yesterday?' do
    after do
      Timecop.return
    end
    it 'should return true if the end_date is the day before' do
      Timecop.freeze(Time.zone.local(2013, 07, 26, 12, 13)) do
        event = create(:event, start_date: '07/24/2013', end_date: '07/25/2013', start_time: '10:00 am', end_time: '2:00 pm')
        expect(event.was_yesterday?).to be_truthy

        event = create(:event, start_date: '07/21/2013', end_date: '07/25/2013', start_time: '10:00 am', end_time: '2:00 pm')
        expect(event.was_yesterday?).to be_truthy
      end
    end

    it "should return false if the event's end_date is other than yesterday" do
      Timecop.freeze(Time.zone.local(2013, 07, 26, 12, 13)) do
        event = create(:event, start_date: '07/26/2013', end_date: '07/26/2013', start_time: '10:00 am', end_time: '2:00 pm')
        expect(event.was_yesterday?).to be_falsey

        event = create(:event, start_date: '07/25/2013', end_date: '07/26/2013', start_time: '10:00 am', end_time: '2:00 pm')
        expect(event.was_yesterday?).to be_falsey

        event = create(:event, start_date: '07/24/2013', end_date: '07/24/2013', start_time: '10:00 am', end_time: '2:00 pm')
        expect(event.was_yesterday?).to be_falsey
      end
    end
  end

  describe 'venue reindexing' do
    let(:campaign) { create(:campaign) }
    let!(:event) { create(:event, campaign: campaign, company: campaign.company) }

    it 'should queue a job to update venue details after a event have been updated if the event data have changed' do
      Kpi.create_global_kpis
      campaign.assign_all_global_kpis
      event.place_id = 1
      event.save # Make sure the event have a place_id
      expect(VenueIndexer).to receive(:perform_async).with(event.venue.id)
      expect do
        field = campaign.form_fields.find { |f| f.kpi_id == Kpi.impressions.id }
        event.update_attributes(results_attributes: { '1' => { form_field_id: field.id, value: '100' } })
      end.to change(FormFieldResult, :count).by(1)
    end

    it 'should queue a job to update venue details after a event have been updated if place_id changed' do
      new_venue = create(:venue, company: event.company)
      expect(VenueIndexer).to receive(:perform_async).with(new_venue.id)
      event.place_id = new_venue.place_id
      expect(event.save).to be_truthy
    end

    it 'should queue a job to update the previous and new event venues' do
      event_with_place = create(:event, campaign: campaign, place: create(:place))
      new_venue = create(:venue, company: event_with_place.company)
      expect(VenueIndexer).to receive(:perform_async).with(event_with_place.venue.id).at_least(:once)
      expect(VenueIndexer).to receive(:perform_async).with(new_venue.id)
      event_with_place.place_id = new_venue.place_id
      expect(event_with_place.save).to be_truthy
    end
  end

  describe 'results_attributes attribute' do
    let(:event) { create(:event) }

    it 'is incremented after updating the results' do
      field = create(:form_field_number, fieldable: event.campaign)
      expect do
        event.update_attributes(results_attributes: { '1' => { form_field_id: field.id, value: '100' } })
      end.to change { event.results_version }.by(1)
    end

    it 'is NOT incremented if the results are not changed' do
      expect do
        expect(
          event.update_attributes(campaign_id: create(:campaign, company: event.company).id,
                                  results_attributes: [])
        ).to be_truthy
      end.to_not change { event.results_version }
    end
  end

  describe '#place_reference=' do
    it 'should not fail if nill' do
      event = build(:event, place: nil)
      event.place_reference = nil
      expect(event.place).to be_nil
    end

    it 'should initialized a new place object' do
      event = build(:event, place: nil)
      expect_any_instance_of(Place).to receive(:fetch_place_data)
      event.place_reference = 'some_reference||some_id'
      expect(event.place).not_to be_nil
      expect(event.place.new_record?).to be_truthy
      expect(event.place.place_id).to eq('some_id')
      expect(event.place.reference).to eq('some_reference')
    end

    it 'should initialized the place object' do
      place = create(:place)
      event = build(:event, place: nil)
      event.place_reference = "#{place.reference}||#{place.place_id}"
      expect(event.place).not_to be_nil
      expect(event.place.new_record?).to be_falsey
      expect(event.place).to eq(place)
    end
  end

  describe '#place_reference' do
    it 'should return the place id if the place is already stored on the DB' do
      place = create(:place)
      event = build(:event, place: place)

      expect(event.place_reference).to eq(place.id)
    end

    it "should return the combination of reference and place_id if it's not stored place" do
      place = build(:place, reference: ':the_reference', place_id: ':the_place_id')
      event = build(:event, place: place)

      expect(event.place_reference).to eq(':the_reference||:the_place_id')
    end

    it 'should return nil if the event has no place associated' do
      event = build(:event, place: nil)

      expect(event.place_reference).to be_nil
    end
  end

  describe '#demographics_graph_data' do
    let(:event) { create(:event, campaign: create(:campaign)) }
    it 'should return the correct results' do
      Kpi.create_global_kpis
      event.campaign.assign_all_global_kpis
      set_event_results(event,
                        gender_male: 35,
                        gender_female: 65,
                        ethnicity_asian: 15,
                        ethnicity_native_american: 23,
                        ethnicity_black: 24,
                        ethnicity_hispanic: 26,
                        ethnicity_white: 12,
                        age_12: 1,
                        age_12_17: 2,
                        age_18_24: 4,
                        age_25_34: 8,
                        age_35_44: 16,
                        age_45_54: 32,
                        age_55_64: 24,
                        age_65: 13
                       )

      expect(event.demographics_graph_data[:gender]).to eq('Female' => 65, 'Male' => 35)
      expect(event.demographics_graph_data[:age]).to eq('< 12' => 1, '12 - 17' => 2, '18 - 24' => 4, '25 - 34' => 8, '35 - 44' => 16, '45 - 54' => 32, '55 - 64' => 24, '65+' => 13)
      expect(event.demographics_graph_data[:ethnicity]).to eq('Asian' => 15.0, 'Black / African American' => 24.0, 'Hispanic / Latino' => 26.0, 'Native American' => 23.0, 'White' => 12.0)
    end
  end

  describe 'validate_modules_ranges' do
    let(:event) { create(:event, campaign: create(:campaign, modules: { 'comments' => { 'name' => 'comments', 'field_type' => 'module', 'settings' => { 'range_min' => '1', 'range_max' => '2' } } })) }

    it 'validates the minimun number of comments' do
      expect(event.validate_modules_ranges).to be_falsey
      expect(event.errors[:base]).to include('Between 1 and 2 comments are required')
    end

    it 'returns valid if the minimun number of comments is covered' do
      event.comments << create(:comment, content: 'Comment #1', commentable: event)
      expect(event.validate_modules_ranges).to be_truthy
      expect(event.errors[:base]).to be_empty
    end
  end

  describe 'survey_statistics' do
    pending 'Add tests for this method'
  end

  describe 'after_remove_member' do
    let(:event) { create(:event) }
    it 'should be called after removign a user from the event' do
      user = create(:company_user, company_id: event.company_id)
      event.users << user
      expect(event).to receive(:after_remove_member).with(user)
      event.users.delete(user)
    end

    it 'should be called after removign a team from the event' do
      team = create(:team, company_id: event.company_id)
      event.teams << team
      expect(event).to receive(:after_remove_member).with(team)
      event.teams.delete(team)
    end

    it 'should reindex all the tasks of the event' do
      user = create(:company_user, company_id: event.company_id)
      other_user = create(:company_user, company_id: event.company_id)
      event.users << user
      event.users << other_user

      tasks = create_list(:task, 3, event: event)
      tasks[1].update_attribute(:company_user_id, other_user.id)
      tasks[2].update_attribute(:company_user_id, user.id)

      expect(tasks[2].reload.company_user_id).to eq(user.id)

      expect(Sunspot).to receive(:index) do |taks_list|
        expect(taks_list.to_a).to be_an_instance_of(Array)
        expect(taks_list.to_a).to match_array(tasks)
      end

      event.users.delete(user)

      expect(tasks[1].reload.company_user_id).to eq(other_user.id)  # This shouldn't be unassigned
      expect(tasks[2].reload.company_user_id).to be_nil
    end

    it 'should unassign all the tasks assigned to any user of the team' do
      team_user1 = create(:company_user, company_id: event.company_id)
      team_user2 = create(:company_user, company_id: event.company_id)
      other_user = create(:company_user, company_id: event.company_id)
      team = create(:team, company_id: event.company_id)
      team.users << [team_user1, team_user2]
      event.teams << team
      event.users << team_user2

      tasks = create_list(:task, 3, event: event)
      tasks[0].update_attribute(:company_user_id, other_user.id)
      tasks[1].update_attribute(:company_user_id, team_user1.id)
      tasks[2].update_attribute(:company_user_id, team_user2.id)

      expect(tasks[1].reload.company_user_id).to eq(team_user1.id)
      expect(tasks[2].reload.company_user_id).to eq(team_user2.id)

      expect(Sunspot).to receive(:index) do |taks_list|
        expect(taks_list.to_a).to be_an_instance_of(Array)
        expect(taks_list.to_a).to match_array(tasks)
      end

      event.teams.delete(team)

      expect(tasks[0].reload.company_user_id).to eq(other_user.id)  # This shouldn't be unassigned
      expect(tasks[1].reload.company_user_id).to be_nil
      expect(tasks[2].reload.company_user_id).to eq(team_user2.id)  # This shouldn't be unassigned either as the user is directly assigned to the event
    end
  end

  describe 'reindex_associated' do
    it 'should update the campaign first and last event dates ' do
      campaign = create(:campaign, first_event_id: nil, last_event_at: nil, first_event_at: nil)
      event = build(:event, campaign: campaign, start_date: '01/23/2019', end_date: '01/25/2019')
      expect(campaign).to receive(:first_event=).with(event)
      expect(campaign).to receive(:last_event=).with(event)
      event.save
    end

    it 'should update only the first event' do
      campaign = create(:campaign, first_event_at: Time.zone.local(2013, 07, 26, 12, 13), last_event_at: Time.zone.local(2013, 07, 29, 14, 13))
      event = build(:event, campaign: campaign, start_date: '07/24/2013', end_date: '07/24/2013')
      expect(campaign).to receive(:first_event=).with(event)
      expect(campaign).not_to receive(:last_event=)
      event.save
    end

    it 'should update only the last event' do
      campaign = create(:campaign, first_event_at: Time.zone.local(2013, 07, 26, 12, 13), last_event_at: Time.zone.local(2013, 07, 29, 14, 13))
      event = build(:event, campaign: campaign, start_date: '07/30/2013', end_date: '07/30/2013')
      expect(campaign).not_to receive(:first_event=)
      expect(campaign).to receive(:last_event=).with(event)
      event.save
    end

    it 'should create a new event data for the event' do
      Kpi.create_global_kpis
      campaign = create(:campaign)
      campaign.assign_all_global_kpis
      event = create(:event, campaign: campaign)
      expect do
        set_event_results(event,
                          impressions: 100,
                          interactions: 101,
                          samples: 102
                         )
      end.to change(EventData, :count).by(1)
      data = EventData.last
      expect(data.impressions).to eq(100)
      expect(data.interactions).to eq(101)
      expect(data.samples).to eq(102)
    end

    it 'should reindex all the tasks of the event when a event is deactivated' do
      campaign = create(:campaign)
      event = create(:event, campaign: campaign)
      user = create(:company_user, company: campaign.company)
      other_user = create(:company_user, company: campaign.company)
      event.users << user
      event.users << other_user

      tasks = [create(:task, event: event)]

      expect(Sunspot).to receive(:index).with(event)
      expect(Sunspot).to receive(:index).with(tasks)
      event.deactivate!
    end
  end

  describe '#activate' do
    let(:event) { create(:event, active: false) }

    it 'should return the active value as true' do
      event.activate!
      event.reload
      expect(event.active).to be_truthy
    end
  end

  describe '#deactivate' do
    let(:event) { create(:event, active: true) }

    it 'should return the active value as false' do
      event.deactivate!
      event.reload
      expect(event.active).to be_falsey
    end
  end

  describe '#result_for_kpi' do
    let(:campaign) { create(:campaign) }
    let(:event) { create(:event, campaign: campaign) }
    it 'should return a new instance of FormFieldResult if the event has not results for the given kpi' do
      Kpi.create_global_kpis
      campaign.assign_all_global_kpis
      result = event.result_for_kpi(Kpi.impressions)
      expect(result).to be_an_instance_of(FormFieldResult)
      expect(result.new_record?).to be_truthy

      # Make sure the result is correctly initialized
      expect(result.form_field_id).not_to be_nil
      expect(result.form_field.kpi).to eql(Kpi.impressions)
      expect(result.value).to be_nil
      expect(result.scalar_value).to eq(0)
    end
  end

  describe '#results_for_kpis' do
    let(:campaign) { create(:campaign) }
    let(:event) { create(:event, campaign: campaign) }
    it 'should return a new instance of FormFieldResult if the event has not results for the given kpi' do
      Kpi.create_global_kpis
      campaign.assign_all_global_kpis
      results = event.results_for_kpis([Kpi.impressions, Kpi.interactions])
      expect(results.count).to eq(2)
      results.each do |result|
        expect(result).to be_an_instance_of(FormFieldResult)
        expect(result.new_record?).to be_truthy

        # Make sure the result is correctly initialized
        expect([Kpi.impressions.id, Kpi.interactions.id]).to include(result.form_field.kpi_id)
        expect(result.form_field_id).not_to be_nil
        expect(result.value).to be_nil
        expect(result.scalar_value).to eq(0)
      end
    end
  end

  describe '#results_for' do
    let(:campaign) { create(:campaign) }
    let(:event) { create(:event, campaign: campaign) }

    it 'should return empty array if no fields given' do
      Kpi.create_global_kpis
      campaign.assign_all_global_kpis
      results = event.results_for([])

      expect(results).to eq([])
    end

    it 'should return empty array if no fields given' do
      Kpi.create_global_kpis
      campaign.assign_all_global_kpis
      results = event.results_for([])

      expect(results).to eq([])
    end

    it 'should only return the results for the given fields' do
      Kpi.create_global_kpis
      campaign.assign_all_global_kpis
      impressions  = campaign.form_fields.find { |f| f.kpi_id == Kpi.impressions.id }
      interactions = campaign.form_fields.find { |f| f.kpi_id == Kpi.interactions.id }
      results = event.results_for([impressions, interactions])

      # Only two results returned
      expect(results.count).to eq(2)

      # They both should be new records
      expect(results.all?(&:new_record?)).to be_truthy

      expect(results.map { |r| r.form_field.kpi_id }).to match_array([Kpi.impressions.id, Kpi.interactions.id])
    end

    it 'should include segmented fields ' do
      Kpi.create_global_kpis
      campaign.assign_all_global_kpis
      results = event.results_for(campaign.form_fields)

      expect(results.map { |r| r.form_field.kpi_id }).to include(Kpi.age.id)
    end
  end

  describe '#event_place_valid?' do
    let(:company) { create(:company) }
    let(:campaign) { create(:campaign, company: company) }
    let(:place_LA) { create(:city, name: 'Los Angeles', state: 'California', country: 'US') }
    let(:place_SF) { create(:city, name: 'San Francisco', state: 'California', country: 'US') }
    let(:bar_in_LA) do
      create(:place, name: 'Bar Testing', route: 'Amargura St.', city: 'Los Angeles',
                     state: 'California', country: 'US', types: %w(establishment bar))
    end

    after do
      User.current = nil
    end

    it 'should only allow create events that are valid for the campaign' do
      campaign.places << place_LA

      event = build(:event, campaign: campaign, company: campaign.company, place: place_SF)
      expect(event.valid?).to be_falsey
      expect(event.errors[:place_reference]).to include(
        'This place has not been approved for the selected campaign. '\
        'Please contact your campaign administrator to request that this be updated.')

      event.place = place_LA
      expect(event.valid?).to be_truthy
    end

    it "should not validate place if the event's place haven't changed" do
      event = create(:event, campaign: campaign, company: campaign.company, place: place_SF)
      expect(event.save).to be_truthy

      campaign.places << place_LA

      expect(event.reload.valid?).to be_truthy
    end

    it 'should allow the event to have a blank place if the user is admin' do
      user = create(:company_user, company: company, role: create(:role, is_admin: true)).user
      user.current_company = company
      User.current = user

      event = build(:event, campaign: campaign, company: company, place: nil)
      expect(event.valid?).to be_truthy
    end

    it 'should NOT allow the event to have a blank place if the user is not admin' do
      user = create(:company_user, company: company, role: create(:role, is_admin: false)).user
      user.current_company = company
      User.current = user

      event = build(:event, campaign: campaign, place: nil)
      expect(event.valid?).to be_falsey
      expect(event.errors[:place_reference]).to include('cannot be blank')
    end

    it 'should NOT allow the event to have a place where the user is not authorized' do
      # The user is autorized to L.A. only
      user = create(:company_user, place_ids: [place_LA.id], company: company, role: create(:role, is_admin: false)).user
      user.current_company = company
      User.current = user

      user.current_company_user.campaigns << campaign

      event = build(:event, campaign: campaign, company: company, place: place_SF)
      expect(event.valid?).to be_falsey
      expect(event.errors[:place_reference]).to include(
        'You do not have permissions to this place. '\
        'Please contact your campaign administrator to request access.')

      event.place = place_LA
      expect(event.valid?).to be_truthy

      event.place = bar_in_LA
      expect(event.valid?).to be_truthy
    end

    it 'should NOT give an error if the place is nil and a non admin is editing the event without modifying the place' do
      # An example: an admin created a event without a place, but another user (not admin) is trying to approve the event
      event = create(:event, campaign: campaign, company: company, place: nil)

      # The user is autorized to L.A. only
      user = create(:company_user, place_ids: [place_LA.id], company: company, role: create(:role, is_admin: false)).user
      user.current_company = company
      User.current = user

      expect(event.valid?).to be_truthy
    end

    it 'allows to create a event in a place that is part of a city that was added to an area for the specific campaign' do
      area = create(:area, company: company)
      campaign.areas << area
      campaign.areas_campaigns.first.update_attributes(inclusions: [place_LA.id])

      event = build(:event, campaign: campaign, company: company, place: bar_in_LA)
      expect(event.valid?).to be_truthy
    end

    it 'does not allow to create a event in inside a city thats place that excluded for the specific campaign' do
      area = create(:area, company: company)
      area.places << place_LA
      campaign.areas << area
      campaign.areas_campaigns.first.update_attributes(exclusions: [place_LA.id])

      event = build(:event, campaign: campaign, company: company, place: bar_in_LA)
      expect(event.valid?).to be_falsey
      expect(event.errors[:place_reference]).to include(
        'This place has not been approved for the selected campaign. '\
        'Please contact your campaign administrator to request that this be updated.')
    end
  end

  describe 'after_validation #set_event_timezone' do
    it 'should set the current timezone for new events' do
      event = build(:event)
      event.valid? # this will trigger the after_validation call
      expect(event.timezone).to eq('America/Los_Angeles')
    end

    it "should set the current timezone if the event's start date is updated" do
      event = nil
      Time.use_zone('America/New_York') do
        event = create(:event)
        expect(event.timezone).to eq('America/New_York')
        expect(event.local_start_at.utc.strftime('%Y-%m-%d %H:%M:%S')).to eql event.read_attribute(:start_at).strftime('%Y-%m-%d %H:%M:%S')
      end
      Time.use_zone('America/Guatemala') do
        event = described_class.last
        event.local_start_at
        event.start_date = '01/22/2019'
        event.valid?  # this will trigger the after_validation call
        expect(event.timezone).to eq('America/Guatemala')
      end
    end

    it "should set the current timezone if the event's end date is updated" do
      event = nil
      Time.use_zone('America/New_York') do
        event = create(:event)
        expect(event.timezone).to eq('America/New_York')
      end
      Time.use_zone('America/Guatemala') do
        event = described_class.last
        event.end_date = '01/22/2019'
        event.valid?  # this will trigger the after_validation call
        expect(event.timezone).to eq('America/Guatemala')
      end
    end

    it "should not update the timezone if the event's dates are not modified" do
      event = nil
      # When creating the event the timezone should be set to America/New_York
      Time.use_zone('America/New_York') do
        event = create(:event, timezone: Time.zone.name)
        expect(event.timezone).to eq('America/New_York')
      end

      # Then if later it's updated on a different timezone, the timezone should not be updated
      # if the dates are not modified
      Time.use_zone('America/Guatemala') do
        event = described_class.last
        expect(event.save).to be_truthy
        expect(event.timezone).to eq('America/New_York')
      end
    end
  end

  describe 'team_members' do
    let(:company) { create(:company) }

    it 'should return all teams and users' do
      event = build(:event, company: company)

      create(:company_user, company: company)
      user1 = create(:company_user, company: company)
      event.users << user1
      user2 = create(:company_user, company: company)
      event.users << user2

      create(:team, company: company)
      team1 = create(:team, company: company)
      event.teams << team1
      team2 = create(:team, company: company)
      event.teams << team2

      expect(event.team_members).to match_array [
        "company_user:#{user1.id}", "company_user:#{user2.id}",
        "team:#{team1.id}", "team:#{team2.id}"
      ]
    end
  end

  describe 'team_members=' do
    let(:company) { create(:company) }

    it 'should correctly assign users and teams' do
      event = build(:event, company: company)
      user1 = create(:company_user, company: company)
      user2 = create(:company_user, company: company)
      team1 = create(:team, company: company)

      event.team_members = [
        "company_user:#{user1.id}", "company_user:#{user2.id}",
        "team:#{team1.id}", 'invalid:222'
      ]

      expect(event.user_ids).to match_array [user1.id, user2.id]
      expect(event.team_ids).to match_array [team1.id]
      expect(event.new_record?).to be_truthy
    end
  end

  describe 'update_activities callback' do
    it 'updates the campaign_id on its activities if the campaign_id change' do
      event = create(:event, campaign: create(:campaign))
      event.campaign.activity_types << create(:activity_type, company: event.company)
      new_campaign = create(:campaign, company: event.company)
      activity = create(:activity,
                        activitable: event,
                        activity_type: event.campaign.activity_types.first,
                        company_user: create(:company_user, company: event.company))
      expect(activity.campaign_id).to eql(event.campaign_id)
      event.campaign = new_campaign
      event.save
      activity.reload
      expect(activity.campaign_id).to eql(new_campaign.id)
    end
  end

  describe 'Phases' do
    let(:campaign) { create(:campaign, company: company) }
    let(:company) { create(:company) }

    describe '#currrent_phase' do
      it 'return plan for events in the future' do
        event = create(:event, start_date: 3.days.from_now.to_s(:slashes),
                               end_date: 3.days.from_now.to_s(:slashes), campaign: campaign)
        expect(event.current_phase).to eql :plan
      end
      it 'returns execute for late events' do
        event = create(:late_event, campaign: campaign)
        expect(event.current_phase).to eql :execute
      end

      it 'returns execute for due events' do
        event = create(:due_event, campaign: campaign)
        expect(event.current_phase).to eql :execute
      end

      it 'returns execute for events happenning today' do
        event = create(:event, start_date: Time.zone.now.to_s(:slashes),
                               end_date: Time.zone.now.to_s(:slashes), campaign: campaign)
        expect(event.current_phase).to eql :execute
      end

      it 'returns results for submitted events' do
        field = create(:form_field_number, fieldable: campaign, required: true)
        event = create(:submitted_event, start_date: Time.zone.now.to_s(:slashes),
                                         end_date: Time.zone.now.to_s(:slashes), campaign: campaign)
        expect(event.current_phase).to eql :results
      end
    end

    describe 'plan_phases' do
      it 'return plan for events in the future' do
        event = create(:event, campaign: campaign)
        expect(event.plan_phases).to eql [
          { id: :info, title: 'Basic Info', complete: true, required: true },
          { id: :contacts, title: 'Contacts', complete: false, required: false },
          { id: :tasks, title: 'Tasks', complete: false, required: false },
          { id: :documents, title: 'Documents', complete: false, required: false }]
      end
    end

    describe 'execute_phases' do
      it 'includes the PER step as complete if campaign has not required form fields' do
        create(:form_field_number, fieldable: campaign, kpi: create(:kpi, company_id: 1), required: false)
        event = create(:event, campaign: campaign)
        expect(event.execute_phases.find { |s| s[:id] == :per }).to include(
          id: :per, title: 'Post Event Recap', complete: true)
      end

      it 'includes the PER step as incomplete if campaign has required form fields without associated results' do
        create(:form_field_number, fieldable: campaign, kpi: create(:kpi, company_id: 1), required: true)
        event = create(:event, campaign: campaign)
        expect(event.execute_phases.find { |s| s[:id] == :per }).to include(
          id: :per, title: 'Post Event Recap', complete: false)
      end

      it 'includes the PER step as complete if campaign has required form fields with associated results' do
        field = create(:form_field_number, fieldable: campaign, kpi: create(:kpi, company_id: 1), required: true)
        event = create(:event, campaign: campaign)
        event.results_for([field]).first.value = 100
        expect(event.execute_phases.find { |s| s[:id] == :per }).to include(
          id: :per, title: 'Post Event Recap', complete: true)
      end

      it 'includes the activities step if campaign have any activity type' do
        event = create(:event, campaign: campaign)
        campaign.activity_types << create(:activity_type, company: company)
        expect(event.execute_phases.find { |s| s[:id] == :activities }).to include(
          id: :activities, title: 'Activities', complete: false)
      end

      it 'does not include the activities step if campaign have no activity types' do
        event = create(:event, campaign: campaign)
        expect(event.execute_phases.find { |s| s[:id] == :activities }).to be_nil
      end

      it 'includes the attendance step if campaign have the module assigned' do
        event = create(:event, campaign: campaign)
        campaign.update_attribute(:modules, 'attendance' => {})
        expect(event.execute_phases.find { |s| s[:id] == :attendance }).to include(
          id: :attendance, title: 'Attendance', complete: false)
      end

      it 'does not include the attendance step if campaign does not have the module assigned' do
        event = create(:event, campaign: campaign)
        expect(event.execute_phases.find { |s| s[:id] == :attendance }).to be_nil
      end

      it 'includes the photos step if campaign have the module assigned' do
        event = create(:event, campaign: campaign)
        campaign.update_attribute(:modules, 'photos' => {})
        expect(event.execute_phases.find { |s| s[:id] == :photos }).to include(
          id: :photos, title: 'Photos', complete: false)
      end

      it 'does not include the photos step if campaign does not have the module assigned' do
        event = create(:event, campaign: campaign)
        expect(event.execute_phases.find { |s| s[:id] == :photos }).to be_nil
      end

      it 'includes the expenses step if campaign have the module assigned' do
        event = create(:event, campaign: campaign)
        campaign.update_attribute(:modules, 'expenses' => {})
        expect(event.execute_phases.find { |s| s[:id] == :expenses }).to include(
          id: :expenses, title: 'Expenses', complete: false)
      end

      it 'does not include the expenses step if campaign does not have the module assigned' do
        event = create(:event, campaign: campaign)
        expect(event.execute_phases.find { |s| s[:id] == :expenses }).to be_nil
      end

      it 'includes the comments step if campaign have the module assigned' do
        event = create(:event, campaign: campaign)
        campaign.update_attribute(:modules, 'comments' => {})
        expect(event.execute_phases.find { |s| s[:id] == :comments }).to include(
          id: :comments, title: 'Consumer Comments', complete: false)
      end

      it 'does not include the comments step if campaign does not have the module assigned' do
        event = create(:event, campaign: campaign)
        expect(event.execute_phases.find { |s| s[:id] == :comments }).to be_nil
      end

      it 'marks the comments module as completed if not range validation and at least one comment exists' do
        event = create(:event, campaign: campaign)
        campaign.update_attribute(:modules, 'comments' => {})
        create(:comment, commentable: event)
        expect(event.execute_phases.find { |s| s[:id] == :comments }[:complete]).to be_truthy
      end

      it 'does not mark the comments module as completed if not comments have been added' do
        event = create(:event, campaign: campaign)
        campaign.update_attribute(:modules, 'comments' => {})
        expect(event.execute_phases.find { |s| s[:id] == :comments }[:complete]).to be_falsey
      end

      it 'does not mark the comments module as completed if does\'t meet the range validations' do
        event = create(:event, campaign: campaign)
        campaign.update_attribute(:modules, 'comments' => { 'settings' => { 'range_max' => 4, 'range_min' => 2 } })
        create(:comment, commentable: event)
        expect(event.execute_phases.find { |s| s[:id] == :comments }[:complete]).to be_falsey
      end

      it 'marks the comments module as completed if meets the range validations' do
        event = create(:event, campaign: campaign)
        campaign.update_attribute(:modules, 'comments' => { 'settings' => { 'range_max' => 4, 'range_min' => 2 } })
        create(:comment, commentable: event)
        create(:comment, commentable: event)
        expect(event.execute_phases.find { |s| s[:id] == :comments }[:complete]).to be_truthy
      end

      it 'does not mark the comments module as completed only a max is specified and not comments have been created' do
        event = create(:event, campaign: campaign)
        campaign.update_attribute(:modules, 'comments' => { 'settings' => { 'range_max' => 4, 'range_min' => nil } })
        expect(event.execute_phases.find { |s| s[:id] == :comments }[:complete]).to be_falsey
      end
    end
  end

  describe '#first_event_expense_created_at' do
    let!(:event) { create :approved_event, created_at: Time.parse('01/01/2010 08:00') }

    context 'when event has no expense' do
      before { expect(event.event_expenses.count).to eq 0 }

      it 'should return event created_at time' do
        expect(event.first_event_expense_created_at).to eql(event.created_at)
      end
    end

    context 'when event has at least one expense' do
      let!(:event_expense1) { create :event_expense, event: event, created_at: Time.parse('01/01/2010 10:00') }
      let!(:event_expense2) { create :event_expense, event: event, created_at: Time.parse('02/01/2010 10:00') }

      before { expect(event.event_expenses.count).to eq 2 }

      it 'should return last event expense created_at time' do
        expect(event.first_event_expense_created_at).to eql(event_expense1.created_at)
      end
    end
  end

  describe '#first_event_expense_created_by' do
    let!(:user1) { create :user }
    let!(:event) { create :approved_event, created_at: Time.parse('01/01/2010 08:00'), created_by: user1 }

    context 'when event has no expense' do
      before { expect(event.event_expenses.count).to eq 0 }

      it 'should return event created_by' do
        expect(event.first_event_expense_created_by.id).to eq user1.id
      end
    end

    context 'when event has at least one expense' do
      let!(:user2) { create :user }
      let!(:event_expense1) { create :event_expense, event: event, created_at: Time.parse('01/01/2010 10:00'), created_by: user2 }
      let!(:event_expense2) { create :event_expense, event: event, created_at: Time.parse('02/01/2010 10:00') }

      before { expect(event.event_expenses.count).to eq 2 }

      it 'should return last event expense created_by' do
        expect(event.first_event_expense_created_by.id).to eq user2.id
      end
    end
  end

  describe '#last_event_expense_updated_at' do
    let!(:event) { create :approved_event, updated_at: Time.parse('01/01/2010 08:00') }

    context 'when event has no expense' do
      before { expect(event.event_expenses.count).to eq 0 }

      it 'should return event updated_at time' do
        expect(event.last_event_expense_updated_at).to eql(event.updated_at)
      end
    end

    context 'when event has at least one expense' do
      let!(:event_expense1) { create :event_expense, event: event, updated_at: Time.parse('01/01/2010 10:00') }
      let!(:event_expense2) { create :event_expense, event: event, updated_at: Time.parse('02/01/2010 10:00') }

      before { expect(event.event_expenses.count).to eq 2 }

      it 'should return last event expense updated_at time' do
        expect(event.last_event_expense_updated_at).to eql(event_expense2.updated_at)
      end
    end
  end

  describe '#last_event_expense_updated_by' do
    let!(:user1) { create :user }
    let!(:event) { create :approved_event, updated_at: Time.parse('01/01/2010 08:00'), updated_by: user1 }

    context 'when event has no expense' do
      before { expect(event.event_expenses.count).to eq 0 }

      it 'should return event updated_by' do
        expect(event.last_event_expense_updated_by.id).to eq user1.id
      end
    end

    context 'when event has at least one expense' do
      let!(:user2) { create :user }
      let!(:event_expense1) { create :event_expense, event: event, updated_at: Time.parse('01/01/2010 10:00') }
      let!(:event_expense2) { create :event_expense, event: event, updated_at: Time.parse('02/01/2010 10:00'), updated_by: user2 }

      before { expect(event.event_expenses.count).to eq 2 }

      it 'should return last event expense updated_by' do
        expect(event.last_event_expense_updated_by.id).to eq user2.id
      end
    end
  end

  describe '#update_active_photos_count' do
    let!(:event) { create :approved_event, active_photos_count: 0 }

    before { allow(event).to receive_message_chain(:photos, :active, :count).and_return 10 }

    it 'should update number of active photos' do
      expect { event.update_active_photos_count }.to change { event.active_photos_count }.from(0).to 10
    end
  end
end
