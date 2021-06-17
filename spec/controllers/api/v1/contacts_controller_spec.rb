require 'rails_helper'

describe Api::V1::ContactsController, type: :controller do
  let(:user) { sign_in_as_user }
  let(:company) { user.company_users.first.company }
  let(:contact) { create(:contact, company: company) }

  before { set_api_authentication_headers user, company }

  describe "GET 'index'", :show_in_doc do
    it 'returns the current user in the results' do
      contact
      create(:contact, company: company)
      get :index, format: :json
      expect(response).to be_success
      expect(json.count).to eql 2
      expect(json.find { |c| c['id'] == contact.id }).to eq('id' => contact.id,
                                                            'first_name' => contact.first_name,
                                                            'last_name' => contact.last_name,
                                                            'full_name' => contact.full_name,
                                                            'title' => contact.title,
                                                            'company_name' => contact.company_name,
                                                            'email' => contact.email,
                                                            'street1' => contact.street1,
                                                            'street2' => contact.street2,
                                                            'phone_number' => contact.phone_number,
                                                            'street_address' => contact.street_address,
                                                            'city' => contact.city,
                                                            'state' => contact.state,
                                                            'zip_code' => contact.zip_code,
                                                            'country' => contact.country,
                                                            'country_name' => contact.country_name)
    end
  end

  describe "GET 'show'" do
    it 'should return the contact details', :show_in_doc do
      get 'show', id: contact.id, format: :json
      expect(response).to render_template('show')
      result = JSON.parse(response.body)
      expect(result['id']).to eql contact.id
      expect(result['first_name']).to eql contact.first_name
    end

    it "should return 404 if the contact doesn't exists" do
      get 'show', id: 999, format: :json
      expect(response.code).to eql '404'
      expect(response).to_not render_template('show')
    end
  end

  describe '#create' do
    it 'should create a new contact', :show_in_doc do
      expect do
        post :create, contact: {
          first_name: 'Juanito',
          last_name: 'Bazooka',
          title: 'Prueba',
          email: 'juanito@Bazooka.com',
          phone_number: '(123) 2322 2222',
          street1: '123 Felicidad St.',
          street2: '2nd floor, #5',
          city: 'Miami',
          state: 'CA',
          country: 'US',
          zip_code: '12345'
        }, format: :json
        expect(response).to be_success
      end.to change(Contact, :count).by(1)
      expect(response).to render_template('show')

      contact = Contact.last
      expect(contact.first_name).to eql('Juanito')
      expect(contact.last_name).to eql('Bazooka')
      expect(contact.title).to eql('Prueba')
      expect(contact.email).to eql('juanito@Bazooka.com')
      expect(contact.phone_number).to eql('(123) 2322 2222')
      expect(contact.street1).to eql('123 Felicidad St.')
      expect(contact.street2).to eql('2nd floor, #5')
      expect(contact.city).to eql('Miami')
      expect(contact.state).to eql('CA')
      expect(contact.country).to eql('US')
      expect(contact.zip_code).to eql('12345')
    end

    it 'should create a new contact with only the resquired fields' do
      expect do
        post :create, contact: {
          first_name: 'Juanito',
          last_name: 'Bazooka',
          city: 'Miami',
          state: 'CA',
          country: 'US'
        }, format: :json
        expect(response).to be_success
      end.to change(Contact, :count).by(1)
      expect(response).to render_template('show')

      contact = Contact.last
      expect(contact.first_name).to eql('Juanito')
      expect(contact.last_name).to eql('Bazooka')
      expect(contact.title).to be_nil
      expect(contact.email).to be_nil
      expect(contact.phone_number).to be_nil
      expect(contact.street1).to be_nil
      expect(contact.street2).to be_nil
      expect(contact.city).to eql('Miami')
      expect(contact.state).to eql('CA')
      expect(contact.country).to eql('US')
      expect(contact.zip_code).to be_nil
    end

    it 'should validate required fields' do
      post :create, contact: {}, format: :json
      expect(response.code).to eql('400')
      expect(response).to_not render_template('show')
    end

    it 'should return code 422 if date/country is not valid' do
      expect do
        post :create, contact: {
          first_name: 'Juanito',
          last_name: 'Bazooka',
          city: 'Miami',
          state: 'XX',
          country: 'YY'
        }, format: :json
        expect(response.code).to eql('422')
      end.to_not change(Contact, :count)
      expect(response).to_not render_template('show')
    end
  end

  describe "PUT 'update'" do
    let(:contact) { create(:contact, company: company) }
    it 'must update the event attributes', :show_in_doc do
      put 'update', id: contact.to_param, contact: {
        first_name: 'William',
        last_name: 'Blake',
        company_name: 'ACME'
      }, format: :json
      expect(assigns(:contact)).to eq(contact)
      expect(response).to be_success

      contact.reload
      expect(contact.first_name).to eq('William')
      expect(contact.last_name).to eq('Blake')
      expect(contact.company_name).to eq('ACME')
    end
  end
end
