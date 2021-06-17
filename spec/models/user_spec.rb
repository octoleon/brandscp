# == Schema Information
#
# Table name: users
#
#  id                        :integer          not null, primary key
#  first_name                :string(255)
#  last_name                 :string(255)
#  email                     :string(255)      default(""), not null
#  encrypted_password        :string(255)      default("")
#  reset_password_token      :string(255)
#  reset_password_sent_at    :datetime
#  remember_created_at       :datetime
#  sign_in_count             :integer          default("0")
#  current_sign_in_at        :datetime
#  last_sign_in_at           :datetime
#  current_sign_in_ip        :string(255)
#  last_sign_in_ip           :string(255)
#  confirmation_token        :string(255)
#  confirmed_at              :datetime
#  confirmation_sent_at      :datetime
#  unconfirmed_email         :string(255)
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  country                   :string(4)
#  state                     :string(255)
#  city                      :string(255)
#  created_by_id             :integer
#  updated_by_id             :integer
#  invitation_token          :string(255)
#  invitation_sent_at        :datetime
#  invitation_accepted_at    :datetime
#  invitation_limit          :integer
#  invited_by_id             :integer
#  invited_by_type           :string(255)
#  current_company_id        :integer
#  time_zone                 :string(255)
#  detected_time_zone        :string(255)
#  phone_number              :string(255)
#  street_address            :string(255)
#  unit_number               :string(255)
#  zip_code                  :string(255)
#  authentication_token      :string(255)
#  invitation_created_at     :datetime
#  avatar_file_name          :string(255)
#  avatar_content_type       :string(255)
#  avatar_file_size          :integer
#  avatar_updated_at         :datetime
#  phone_number_verified     :boolean
#  phone_number_verification :string(255)
#

require 'rails_helper'

describe User, type: :model do
  it { is_expected.to have_many(:company_users) }

  it { is_expected.to allow_value('guilleva@gmail.com').for(:email) }

  it { is_expected.to allow_value('Avalidpassword1').for(:password) }
  it { is_expected.to allow_value('validPassw0rd').for(:password) }
  it { is_expected.not_to allow_value('Invalidpassword').for(:password).with_message(/should have at least one digit/) }
  it { is_expected.not_to allow_value('invalidpassword1').for(:password).with_message(/should have at least one upper case letter/) }
  it { is_expected.to validate_confirmation_of(:password) }
  it { is_expected.not_to validate_presence_of(:detected_time_zone) }

  describe 'email uniqness' do
    before do
      @user = create(:user)
    end
    it { is_expected.to validate_uniqueness_of(:email) }
  end

  describe 'validations when inviting user' do
    context do
      before { subject.inviting_user = true }
      it { is_expected.not_to validate_presence_of(:country) }
      it { is_expected.not_to validate_presence_of(:state) }
      it { is_expected.not_to validate_presence_of(:city) }
      it { is_expected.not_to validate_presence_of(:time_zone) }
      it { is_expected.not_to validate_presence_of(:password) }
    end
  end

  describe 'validations when editing another user' do
    context do
      before { subject.updating_user = true }
      it { is_expected.not_to validate_presence_of(:phone_number) }
      it { is_expected.not_to validate_presence_of(:country) }
      it { is_expected.not_to validate_presence_of(:state) }
      it { is_expected.not_to validate_presence_of(:city) }
      it { is_expected.not_to validate_presence_of(:street_address) }
      it { is_expected.not_to validate_presence_of(:city) }
      it { is_expected.not_to validate_presence_of(:zip_code) }
      it { is_expected.not_to validate_presence_of(:password) }
    end
  end

  describe 'validations when accepting an invitation' do
    context do
      before do
        subject.invitation_accepted_at = nil
        subject.accepting_invitation = true
      end
      it { is_expected.to validate_presence_of(:country) }
      it { is_expected.to validate_presence_of(:state) }
      it { is_expected.to validate_presence_of(:city) }
      it { is_expected.to validate_presence_of(:time_zone) }
      it { is_expected.to validate_presence_of(:password) }
    end
  end

  describe 'validations when editing a user' do
    context do
      before do
        subject.invitation_accepted_at = Time.now
      end
      it { is_expected.to validate_presence_of(:country) }
      it { is_expected.to validate_presence_of(:state) }
      it { is_expected.to validate_presence_of(:city) }
      it { is_expected.to validate_presence_of(:time_zone) }
      it { is_expected.not_to validate_presence_of(:password) }
    end
  end

  describe 'validations when resetting a password' do
    context do
      before do
        subject.inviting_user = true
        subject.reset_password_token = '8cef675c61216e36ef6192cda70b00832fc82dd2c25de962bf919fafd70121d3'
        subject.reset_password_sent_at = '2015-09-17 16:36:03.553256'
      end
      it { is_expected.not_to validate_presence_of(:phone_number) }
      it { is_expected.not_to validate_presence_of(:country) }
      it { is_expected.not_to validate_presence_of(:state) }
      it { is_expected.not_to validate_presence_of(:city) }
      it { is_expected.not_to validate_presence_of(:street_address) }
      it { is_expected.not_to validate_presence_of(:city) }
      it { is_expected.not_to validate_presence_of(:zip_code) }
    end
  end

  describe '#full_name' do
    let(:user) { build(:user, first_name: 'Juanito', last_name: 'Perez') }

    it 'should return the first_name and last_name concatenated' do
      expect(user.full_name).to eq('Juanito Perez')
    end

    it "should return only the first_name if it doesn't have last_name" do
      user.last_name = nil
      expect(user.full_name).to eq('Juanito')
    end

    it "should return only the last_name if it doesn't have first_name" do
      user.first_name = nil
      expect(user.full_name).to eq('Perez')
    end
  end

  describe '#country_name' do
    it 'should return the correct country name' do
      user = build(:user, country: 'US')
      expect(user.country_name).to eq('United States')
    end

    it "should return nil if the user doesn't have a country" do
      user = build(:user, country: nil)
      expect(user.country_name).to be_nil
    end

    it 'should return nil if the user has an invalid country' do
      user = build(:user, country: 'XYZ')
      expect(user.country_name).to be_nil
    end
  end

  describe '#state_name' do
    it 'should return the correct state name' do
      user = build(:user, country: 'US', state: 'FL')
      expect(user.state_name).to eq('Florida')
    end

    it "should return nil if the user doesn't have a state" do
      user = build(:user, country: 'US', state: nil)
      expect(user.state_name).to be_nil
    end

    it 'should return nil if the user has an invalid state' do
      user = build(:user, country: 'US', state: 'XYZ')
      expect(user.state_name).to be_nil
    end
  end

  describe '#companies_active_role' do
    it "should return the user's companies sorted by name for company users and roles that are active" do
      user = create(:user, first_name: 'Juanito', last_name: 'Perez')
      companyB = create(:company, name: 'B Company')
      companyC = create(:company, name: 'C Company')
      companyA = create(:company, name: 'A Company')
      company_users = [
        create(:company_user, company: companyA),
        create(:company_user, company: companyB, active: false),
        create(:company_user, company: companyC)
      ]
      company_users.each do |company_user|
        user.company_users << company_user
      end

      companies = user.companies_active_role
      expect(companies[0]).to eq(companyA)
      expect(companies[1]).to eq(companyC)
    end
  end

  describe 'is_super_admin?' do
    it 'should return true if the current role is admin' do
      company = create(:company)
      user    = create(:user, current_company_id: company.id,
                              company_users: [
                                create(:company_user,
                                       company: company,
                                       role: create(:role, is_admin: true))])
      expect(user.is_super_admin?).to be_truthy
    end

    it 'should return false if the current role is admin' do
      company = create(:company)
      user    = create(:user, current_company_id: company.id,
                              company_users: [
                                create(:company_user,
                                       company: company,
                                       role: create(:role, is_admin: false))])
      expect(user.is_super_admin?).to be_falsey
    end
  end
end
