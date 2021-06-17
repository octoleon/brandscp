require 'rails_helper'

describe Api::V1::BrandsController, type: :controller do
  let(:user) { sign_in_as_user }
  let(:company_user) { user.company_users.first }
  let(:company) { company_user.company }

  before { set_api_authentication_headers user, company }

  describe '#index' do
    it 'returns a list of brands' do
      brand1 = create(:brand, name: 'Cacique', company_id: company.to_param)
      create :membership, company_user: company_user, memberable: brand1
      brand2 = create(:brand, name: 'Nikolai', company_id: company.to_param)
      create :membership, company_user: company_user, memberable: brand2

      get 'index', format: :json
      expect(response).to be_success
      result = JSON.parse(response.body)

      expect(result).to match_array([{ 'id' => brand1.id, 'name' => 'Cacique', 'active' => true },
                                     { 'id' => brand2.id, 'name' => 'Nikolai', 'active' => true }])
    end

    it 'returns a list of brands for campaign' do
      campaign = create(:campaign, company: company)
      campaign2 = create(:campaign, company: company)
      brand1 = create(:brand, name: 'Cacique', company_id: company.to_param)
      create :membership, company_user: company_user, memberable: brand1
      brand2 = create(:brand, name: 'Imperial', company_id: company.to_param)
      create :membership, company_user: company_user, memberable: brand2
      campaign2.brands << create(:brand, name: 'Pilsen', company_id: company.to_param)
      campaign.brands << brand1
      campaign.brands << brand2

      get 'index', campaign_id: campaign.to_param, format: :json
      expect(response).to be_success
      result = JSON.parse(response.body)
      expect(result.count).to eql 2

      expect(result).to match_array([{ 'id' => brand1.id, 'name' => 'Cacique', 'active' => true },
                                     { 'id' => brand2.id, 'name' => 'Imperial', 'active' => true }])
    end
  end

  describe '#marques' do
    it 'returns a list of marques' do
      brand = create(:brand, name: 'Cacique', company_id: company.to_param)
      create :membership, company_user: company_user, memberable: brand
      marque1 = create(:marque, name: 'Marque #1 for Cacique', brand: brand)
      marque2 = create(:marque, name: 'Marque #2 for Cacique', brand: brand)

      get 'marques', id: brand.to_param, format: :json
      expect(response).to be_success
      result = JSON.parse(response.body)

      expect(result).to match_array([{ 'id' => marque1.id, 'name' => 'Marque #1 for Cacique' },
                                     { 'id' => marque2.id, 'name' => 'Marque #2 for Cacique' }])
    end
  end
end
