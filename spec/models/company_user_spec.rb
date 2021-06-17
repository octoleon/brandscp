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

require 'rails_helper'

describe CompanyUser, type: :model do
  it { is_expected.to belong_to(:user) }
  it { is_expected.to belong_to(:company) }
  it { is_expected.to belong_to(:role) }
  it { is_expected.to have_many(:tasks) }
  it { is_expected.to have_many(:memberships) }
  it { is_expected.to have_many(:teams).through(:memberships) }
  it { is_expected.to have_many(:campaigns).through(:memberships) }
  it { is_expected.to have_many(:events).through(:memberships) }

  it { is_expected.to validate_presence_of(:role_id) }
  it { is_expected.to validate_numericality_of(:role_id) }

  it { is_expected.to validate_presence_of(:company_id) }
  it { is_expected.to validate_numericality_of(:company_id) }

  describe '#deactivate' do
    it 'should deactivate the status of the user on the current company' do
      user = create(:company_user, active: true)
      user.deactivate!
      expect(user.reload.active).to be_falsey
    end

    it 'should activate the status of the user on the current company' do
      user = create(:company_user, active: false)
      user.activate!
      expect(user.reload.active).to be_truthy
    end
  end

  describe '#by_teams scope' do
    it 'should return users that belongs to the give teams' do
      users = [
        create(:company_user),
        create(:company_user)
      ]
      other_users = [
        create(:company_user)
      ]
      team = create(:team)
      other_team = create(:team)
      users.each { |u| team.users << u }
      other_users.each { |u| other_team.users << u }
      expect(described_class.by_teams(team).all).to match_array(users)
      expect(described_class.by_teams(other_team).all).to match_array(other_users)
      expect(described_class.by_teams([team, other_team]).all).to match_array(users + other_users)
    end
  end

  describe '#by_events scope' do
    it 'should return users that assigned to the specific events' do
      event = create(:event)
      users = [
        create(:company_user, company: event.company),
        create(:company_user, company: event.company)
      ]
      other_users = [
        create(:company_user, company: event.company)
      ]
      other_event = create(:event, company: event.company)
      event.users << users
      other_event.users << other_users
      expect(described_class.by_events(event).all).to match_array(users)
      expect(described_class.by_events(other_event).all).to match_array(other_users)
      expect(described_class.by_events([event, other_event]).all).to match_array(users + other_users)
    end
  end

  describe '#in_event_team scope' do
    it 'should return users that assigned to a specific event' do
      event = create(:event)
      users = [
        create(:company_user, company: event.company),
        create(:company_user, company: event.company)
      ]
      other_users = [
        create(:company_user, company: event.company)
      ]
      other_event = create(:event, company: event.company)
      event.users << users
      other_event.users << other_users
      expect(described_class.in_event_team(event).all).to match_array(users)
      expect(described_class.in_event_team(other_event).all).to match_array(other_users)
    end

    it 'should return users that are part of teams that are assigned to a specific event' do
      event = create(:event)
      team = create(:team, company: event.company)
      other_team = create(:team, company: event.company)
      users = [
        create(:company_user, company: event.company),
        create(:company_user, company: event.company)
      ]
      other_users = [
        create(:company_user, company: event.company)
      ]
      team.users << users
      other_team.users << other_users
      other_event = create(:event, company: event.company)
      event.teams << team
      other_event.teams << other_team
      expect(described_class.in_event_team(event).all).to match_array(users)
      expect(described_class.in_event_team(other_event).all).to match_array(other_users)
    end
  end

  describe '#accessible_campaign_ids' do
    describe 'as a non admin user' do
      let(:user)      { create(:company_user, company_id: 1, role: create(:role, is_admin: false)) }
      let(:brand)     { create(:brand) }
      let(:campaign)  { create(:campaign, company_id: 1) }
      let(:portfolio) { create(:brand_portfolio) }

      it 'should return the ids of campaigns assigend to the user' do
        user.campaigns << campaign
        expect(user.accessible_campaign_ids).to eq([campaign.id])
      end

      it 'should return the ids of campaigns of a brand assigend to the user' do
        campaign.brands << brand
        user.brands << brand
        expect(user.accessible_campaign_ids).to eq([campaign.id])
      end

      it 'should not return campaigns for inactive brands' do
        brand.update_attribute(:active, false)
        campaign.brands << brand
        user.brands << brand
        expect(user.accessible_campaign_ids).to be_empty
      end

      it 'should return the ids of campaigns of a brand portfolio assigned to the user' do
        campaign.brand_portfolios << portfolio
        user.brand_portfolios << portfolio
        expect(user.accessible_campaign_ids).to eq([campaign.id])
      end

      it 'should not return campaigns for inactive brand portfolios' do
        portfolio.update_attribute(:active, false)
        campaign.brand_portfolios << portfolio
        user.brand_portfolios << portfolio
        expect(user.accessible_campaign_ids).to be_empty
      end
    end

    describe 'as an admin user' do
      let(:user)      { create(:company_user, company: create(:company)) }

      it 'should return the ids of campaigns assigend to the user' do
        campaigns = create_list(:campaign, 3, company: user.company)
        create_list(:campaign, 2, company_id: user.company.id + 1)
        expect(user.accessible_campaign_ids).to match_array campaigns.map(&:id)
      end
    end
  end

  describe '#allowed_to_access_place?' do
    let(:user)      { create(:company_user, company_id: 1, role: create(:role, is_admin: false)) }
    let(:campaign)  { create(:campaign, company_id: 1) }
    let(:place)  { create(:place, country: 'US', state: 'California', city: 'Los Angeles') }

    it "should return false if the user doesn't places associated" do
      expect(user.allowed_to_access_place?(place)).to be_falsey
    end

    it 'should return true if the user has access to the city' do
      user.places << create(:place, country: 'US', state: 'California', city: 'Los Angeles', types: ['locality'])
      expect(user.allowed_to_access_place?(place)).to be_truthy
    end

    it "should return true if the user has access to an area that includes the place's city" do
      city = create(:place, country: 'US', state: 'California', city: 'Los Angeles', types: ['locality'])
      area = create(:area, company_id: 1)
      area.places << city
      user.areas << area
      expect(user.allowed_to_access_place?(place)).to be_truthy
    end

    it 'should work with places that are not yet saved' do
      place = build(:place, country: 'US', state: 'California', city: 'Los Angeles')
      city = create(:place, country: 'US', state: 'California', city: 'Los Angeles', types: ['locality'])
      area = create(:area, company_id: 1)
      area.places << city
      user.areas << area
      expect(user.allowed_to_access_place?(place)).to be_truthy
    end
  end

  describe '#accessible_places' do
    let(:user) { create(:company_user, company_id: 1, role: create(:role, is_admin: false)) }
    it 'should return the id of the places assocaited to the user' do
      create(:place)
      place = create(:place)
      create(:place)
      user.places << place
      expect(user.accessible_places).to include(place.id)
    end
    it 'should return the id of the places of areas associated to the user' do
      create(:place)
      place = create(:place)
      create(:place)
      create(:area, company_id: user.company_id)
      area = create(:area, company_id: user.company_id)
      area.places << place
      user.areas << area
      expect(user.accessible_places).to include(place.id)
    end
  end

  describe '#accessible_locations' do
    let(:user) { create(:company_user, company_id: 1, role: create(:role, is_admin: false)) }
    it 'should return the location id of the city' do
      city = create(:place, country: 'US', state: 'California', city: 'Los Angeles', types: ['locality'])
      user.places << city
      expect(user.accessible_locations).to include(city.location_id)
    end
    it "should return the location id of the city if belongs to an user's area" do
      city = create(:place, country: 'US', state: 'California', city: 'Los Angeles', types: ['locality'])
      area = create(:area, company_id: user.company_id)
      area.places << city
      user.areas << area
      expect(user.accessible_locations).to include(city.location_id)
    end
    it 'should not include the location id of the venues' do
      bar = create(:place, country: 'US', state: 'California', city: 'Los Angeles', types: %w(establishment bar))
      user.places << bar
      expect(user.accessible_locations).to be_empty
    end
  end

  describe '#allow_notification?' do
    let(:user) do
      create(:company_user, company_id: 1,
                            role: create(:role, is_admin: false))
    end

    it 'should return false if the user is not allowed to receive a notification' do
      expect(user.allow_notification?('new_campaign_sms')).to be_falsey
    end

    it 'should return true if the user is allowed to receive a notification' do
      user.update_attributes(notifications_settings: ['new_campaign_sms'],
                             user_attributes: { phone_number_verified: true })
      expect(user.allow_notification?('new_campaign_sms')).to be_truthy
    end

    describe 'user without phone number' do
      it 'should return true if the user is allowed to receive a notification' do
        user.user.phone_number = nil
        user.update_attributes(notifications_settings: %w(new_campaign_app new_campaign_sms))
        expect(user.allow_notification?('new_campaign_app')).to be_truthy
        expect(user.allow_notification?('new_campaign_sms')).to be_falsey
      end
    end
  end

  describe '#notification_setting_permission?' do
    let(:user) { create(:company_user, company_id: 1, role: create(:role, is_admin: false)) }

    it "should return false if the user hasn't the correct permissions" do
      expect(user.notification_setting_permission?('new_campaign')).to be_falsey
    end

    it 'should return true if the user has the correct permissions' do
      user.role.permissions.create(action: :read, subject_class: 'Campaign', mode: 'campaigns')
      expect(user.notification_setting_permission?('new_campaign')).to be_truthy
    end
  end

  describe '#with_notifications' do
    it 'should return empty if no users have the any of the notifications enabled' do
      create(:company_user)
      expect(described_class.with_notifications(['some_notification'])).to be_empty
    end

    it 'should return all users with any of the notifications enabled' do
      user1 = create(:company_user,
                     notifications_settings: %w(notification2 notification1))

      user2 = create(:company_user,
                     notifications_settings: %w(notification3 notification4 notification1))

      expect(described_class.with_notifications(['notification2'])).to match_array [user1]

      expect(described_class.with_notifications(['notification1'])).to match_array [user1, user2]
    end
  end

  describe '#campaigns_changed' do
    let(:company) { create(:company) }
    let(:company_user) { create(:company_user, company: company) }
    let(:campaign) { create(:campaign, company: company) }
    let(:brand) { create(:brand, company: company) }
    let(:brand_portfolio) { create(:brand_portfolio, company: company) }

    it 'should clear cache after adding campaigns to user' do
      expect(Rails.cache).to receive(:delete).with("user_accessible_campaigns_#{company_user.id}")
      expect(Rails.cache).to receive(:delete).with("user_notifications_#{company_user.id}").at_least(:once)
      company_user.campaigns << campaign
    end

    it 'should clear cache after adding brands to user' do
      expect(Rails.cache).to receive(:delete).with("user_accessible_campaigns_#{company_user.id}")
      expect(Rails.cache).to receive(:delete).with("user_notifications_#{company_user.id}").at_least(:once)
      company_user.brands << brand
    end

    it 'should clear cache after adding brand portfolios to user' do
      expect(Rails.cache).to receive(:delete).with("user_accessible_campaigns_#{company_user.id}")
      expect(Rails.cache).to receive(:delete).with("user_notifications_#{company_user.id}").at_least(:once)
      company_user.brand_portfolios << brand_portfolio
    end

    it 'should clear cache after adding campaigns to user' do
      company_user.campaigns << campaign
      expect(Rails.cache).to receive(:delete).with("user_accessible_campaigns_#{company_user.id}")
      expect(Rails.cache).to receive(:delete).with("user_notifications_#{company_user.id}").at_least(:once)
      company_user.campaigns.destroy campaign
    end

    it 'should clear cache after adding brands to user' do
      company_user.brands << brand
      expect(Rails.cache).to receive(:delete).with("user_accessible_campaigns_#{company_user.id}")
      expect(Rails.cache).to receive(:delete).with("user_notifications_#{company_user.id}").at_least(:once)
      company_user.brands.destroy brand
    end

    it 'should clear cache after adding brand portfolios to user' do
      company_user.brand_portfolios << brand_portfolio
      expect(Rails.cache).to receive(:delete).with("user_accessible_campaigns_#{company_user.id}")
      expect(Rails.cache).to receive(:delete).with("user_notifications_#{company_user.id}").at_least(:once)
      company_user.brand_portfolios.destroy brand_portfolio
    end
  end

  describe '#filter_setting_present' do
    let(:company) { create(:company) }
    let(:company_user) { create(:company_user, company: company) }

    it 'should include only custom filters for events' do
      expect(company_user.filter_setting_present('show_inactive_items', 'events')).to be_falsey
      create(:filter_setting,
             company_user_id: company_user.to_param, apply_to: 'events',
             settings: %w(show_inactive_items
                          campaigns_events_present
                          brands_events_present))
      expect(company_user.filter_setting_present('show_inactive_items', 'events')).to be_truthy
      expect(company_user.filter_setting_present('campaigns_events_present', 'events')).to be_truthy
      expect(company_user.filter_setting_present('brands_events_present', 'events')).to be_truthy
      expect(company_user.filter_setting_present('users_events_present', 'events')).to be_falsey
    end
  end

  describe 'default notifications settings' do
    it 'should assign all notifications settings on creation ' do
      user = create(:company_user, notifications_settings: nil)
      expect(user.notifications_settings).not_to be_empty
      expect(user.notifications_settings.length).to eql CompanyUser::NOTIFICATION_SETTINGS_TYPES.length
      expect(user.notifications_settings).to include('event_recap_due_app')
    end
  end

  describe '#accessible_brand_portfolios_brand_ids' do
    let!(:company) { create :company }
    let!(:company_user) { create :company_user, company: company }

    let!(:brand1) { create :brand, company: company, active: true }
    let!(:brand2) { create :brand, company: company, active: true }
    let!(:brand_portfolio1) { create :brand_portfolio, company: company }
    let!(:brand_portfolio2) { create :brand_portfolio, company: company }
    let!(:brand_portfolios_brand1) { create :brand_portfolios_brand, brand: brand1, brand_portfolio: brand_portfolio1 }
    let!(:brand_portfolios_brand2) { create :brand_portfolios_brand, brand: brand2, brand_portfolio: brand_portfolio2 }

    before { create :membership, company_user: company_user, memberable: brand_portfolio1 }
    before { create :membership, company_user: company_user, memberable: brand_portfolio2 }

    it 'should return brand ids from brand portfolio brands' do
      expect(company_user.accessible_brand_portfolios_brand_ids).to match_array([brand1.id, brand2.id])
    end
  end

  describe '#accessible_brand_ids' do
    let!(:company) { create :company }

    let!(:company_user) { create :company_user, company: company }

    let!(:brand1) { create :brand, company: company, active: true }
    let!(:brand2) { create :brand, company: company, active: true }

    context 'when user is an admin' do
      before { allow(company_user).to receive(:is_admin?).and_return true }

      it 'should return all brand ids' do
        expect(company_user.accessible_brand_ids).to match_array([brand1.id, brand2.id])
      end
    end

    context 'when user is not an admin' do
      before { allow(company_user).to receive(:is_admin?).and_return false }

      let!(:brand3) { create :brand, company: company, active: true }

      before { company_user.brands << brand1 }
      before { company_user.brands << brand2 }
      before { company_user.brands << brand3 }

      before { allow(company_user).to receive(:accessible_brand_portfolios_brand_ids).and_return([brand3.id, brand2.id]) }

      it 'should return user brand ids and portfolio brand ids' do
        expect(company_user.accessible_brand_ids).to match_array([brand1.id, brand2.id, brand3.id])
      end
    end
  end
end
