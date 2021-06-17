require 'rails_helper'

describe PlacesController, type: :controller do
  let(:user) { sign_in_as_user }
  let(:company) { user.companies.first }
  let(:campaign) { create(:campaign, company: company) }
  let(:company_user) { create(:company_user, company: company) }
  let(:area) { create(:area, company: company) }
  let(:place) { create(:place) }

  before { user }

  describe "POST 'create'" do
    it 'returns http success' do
      expect_any_instance_of(Place).to receive(:fetch_place_data).at_least(:once).and_return(true)
      xhr :post, 'create', area_id: area.id, place: { reference: ':ref||:id' }, format: :js
      expect(response).to be_success
    end

    it 'should create a new place that is no found in google places' do
      expect_any_instance_of(Place).to receive(:fetch_place_data).and_return(true)
      expect_any_instance_of(GooglePlaces::Client).to receive(:spots).and_return([])
      expect_any_instance_of(described_class).to receive(:open)
        .and_return(double(read: ActiveSupport::JSON.encode('results' => [
          { 'geometry' => { 'location' => { 'lat' => '1.2322', lng: '-3.23455' } } }])))
      expect do
        xhr :post, 'create', area_id: area.to_param, add_new_place: true, place: {
          name: "Guille's place", street_number: '123 st', route: 'xyz 321',
          city: 'Curridabat', state: 'San José', zipcode: '12345',
          types: 'bar',
          country: 'CR' }, format: :js
      end.to change(Place, :count).by(1)
      place = Place.last
      expect(place.name).to eql "Guille's place"
      expect(place.street_number).to eql '123 st'
      expect(place.route).to eql 'xyz 321'
      expect(place.city).to eql 'Curridabat'
      expect(place.state).to eql 'San José'
      expect(place.zipcode).to eql '12345'
      expect(place.country).to eql 'CR'
      expect(place.latitude).to eql 1.2322
      expect(place.longitude).to eql -3.23455
      expect(place.locations.count).to eql 4

      expect(area.places).to match_array([place])
    end

    it 'should create a new place wih address that can not be found by google search' do
      expect_any_instance_of(Place).to receive(:fetch_place_data).and_return(true)
      expect_any_instance_of(GooglePlaces::Client).to receive(:spots).and_return([])
      expect_any_instance_of(described_class).to receive(:open)
                                                 .and_return(double(read: ActiveSupport::JSON.encode('results' => [
          { 'geometry' => { 'location' => { 'lat' => '1.2322', lng: '-3.23455' } } }])))
      expect do
        xhr :post, 'create', area_id: area.to_param, add_new_place: true, place: {
            name: "Bar Da", street_number: 'Seogyo dong 365-12', route: '',
            city: 'Seoul', state: 'Seoul Teugbyeolsi', zipcode: '121-893',
            types: 'bar',
            country: 'KR' }, format: :js
      end.to change(Place, :count).by(1)
      place = Place.last
      expect(place.name).to eql "Bar Da"
      expect(place.street_number).to eql 'Seogyo dong 365-12'
      expect(place.route).to eql ''
      expect(place.city).to eql 'Seoul'
      #we're not comparing state as we omitted it in intention
      expect(place.zipcode).to eql '121-893'
      expect(place.country).to eql 'KR'
      expect(place.latitude).to eql 1.2322
      expect(place.longitude).to eql -3.23455
      expect(place.locations.count).to eql 3

      expect(area.places).to match_array([place])
    end

    it 'should allow to create places with custom venue values' do
      expect_any_instance_of(Place).to receive(:fetch_place_data).and_return(true)
      expect_any_instance_of(GooglePlaces::Client).to receive(:spots).and_return([])
      expect_any_instance_of(described_class).to receive(:open)
        .and_return(double(read: ActiveSupport::JSON.encode('results' => [
          { 'geometry' => { 'location' => { 'lat' => '1.2322', lng: '-3.23455' } } }])))

      ff = create(:form_field_number, fieldable: create(:entity_form, entity: 'Venue', company_id: company.id))
      expect do
        expect do
          expect do
            xhr :post, 'create', area_id: area.to_param, add_new_place: true, place: {
              name: "Guille's place", street_number: '123 st', route: 'xyz 321',
              city: 'Curridabat', state: 'San José', zipcode: '12345',
              types: 'bar', country: 'CR', venues_attributes: { '0' =>
                { company_id: company.id, web_address: 'www.guilles.com',
                  place_price_level: '2', phone_number: '(404) 234234234',
                  hours_fields_attributes: {
                    '0' => { day: '1', hour_open: '0600', hour_close: '0000', '_destroy' => 'false' }
                  }, results_attributes: { '0' =>
                  { form_field_id: ff.id, value: 1 }
                }
              } } }, format: :js
          end.to change(Place, :count).by(1)
        end.to change(Venue, :count).by(1)
      end.to change(FormFieldResult, :count).by(1)
      place = Place.last
      venue = Venue.last
      expect(place.name).to eql "Guille's place"
      expect(place.street_number).to eql '123 st'
      expect(place.route).to eql 'xyz 321'
      expect(place.city).to eql 'Curridabat'
      expect(place.state).to eql 'San José'
      expect(place.zipcode).to eql '12345'
      expect(place.country).to eql 'CR'
      expect(place.latitude).to eql 1.2322
      expect(place.longitude).to eql -3.23455
      expect(place.locations.count).to eql 4
      expect(venue.website).to eql 'http://www.guilles.com'
      expect(venue.price_level).to eql 2
      expect(venue.phone_number).to eql '(404) 234234234'
      expect(venue.opening_hours.count).to eql 1
      expect(Venue.last.results_for([ff]).first.value).to eql '1'

      expect(area.places).to match_array([place])
    end

    context 'the place already exists on API' do
      it "save the user's address data if spot have not address associated" do
        expect_any_instance_of(GooglePlaces::Client).to receive(:spot).and_return(double(
          name: 'APIs place name', lat: '1.111', lng: '2.222', formatted_address: 'api fmt address', types: ['bar'],
          address_components: nil
        ))
        expect_any_instance_of(GooglePlaces::Client).to receive(:spots)
          .and_return([double(place_id: '123', name: "Guille's place", reference: 'XYZ')])
        expect_any_instance_of(described_class).to receive(:open)
          .and_return(double(read: ActiveSupport::JSON.encode('results' => [
            { 'geometry' => { 'location' => { 'lat' => '1.2322', lng: '-3.23455' } } }])))
        expect do
          xhr :post, 'create', area_id: area.id, add_new_place: true, place: {
            name: "Guille's place", street_number: '123 st',
            route: 'xyz 321', city: 'Curridabat', state: 'San José',
            zipcode: '12345', country: 'CR' }, format: :js
        end.to change(Place, :count).by(1)
        place = Place.last
        expect(place.name).to eql 'APIs place name'
        expect(place.street_number).to eql '123 st'
        expect(place.route).to eql 'xyz 321'
        expect(place.city).to eql 'Curridabat'
        expect(place.state).to eql 'San José'
        expect(place.zipcode).to eql '12345'
        expect(place.country).to eql 'CR'
        expect(place.place_id).to eql '123'
        expect(place.reference).to eql 'XYZ'
        expect(place.latitude).to eql 1.111
        expect(place.longitude).to eql 2.222
        expect(place.locations.count).to eql 4

        expect(area.places).to eq([place])
      end

      it 'creates the place and associate its to the campaign' do
        Kpi.create_global_kpis
        expect_any_instance_of(GooglePlaces::Client).to receive(:spot).and_return(double(
          name: 'APIs place name', lat: '1.111', lng: '2.222', formatted_address: 'api fmt address', types: ['bar'],
          address_components: [
            { 'types' => ['country'], 'short_name' => 'US', 'long_name' => 'United States' },
            { 'types' => ['administrative_area_level_1'], 'short_name' => 'CA', 'long_name' => 'CA' },
            { 'types' => ['locality'], 'short_name' => 'Manhattan Beach', 'long_name' => 'Manhattan Beach' },
            { 'types' => ['postal_code'], 'short_name' => '12345', 'long_name' => '12345' },
            { 'types' => ['street_number'], 'short_name' => '123 st', 'long_name' => '123 st' },
            { 'types' => ['route'], 'short_name' => 'xyz 321', 'long_name' => 'xyz 321' }
          ]
        ))

        expect do
          xhr :post, 'create', campaign_id: campaign.id, place: { reference: 'XXXXXXXXXXX||YYYYYYYYYY' }, format: :js
        end.to change(Place, :count).by(1)
        place = Place.last
        expect(place.name).to eql 'APIs place name'
        expect(place.formatted_address).to eql 'api fmt address'
        expect(place.street_number).to eql '123 st'
        expect(place.route).to eql 'xyz 321'
        expect(place.city).to eql 'Manhattan Beach'
        expect(place.state).to eql 'California'
        expect(place.zipcode).to eql '12345'
        expect(place.country).to eql 'US'
        expect(place.place_id).to eql 'YYYYYYYYYY'
        expect(place.reference).to eql 'XXXXXXXXXXX'
        expect(place.latitude).to eql 1.111
        expect(place.longitude).to eql 2.222
        expect(place.types).to eql ['bar']
        expect(place.locations.count).to eql 4
        expect(place.locations.map(&:path)).to match_array [
          'north america', 'north america/united states', 'north america/united states/california',
          'north america/united states/california/manhattan beach'
        ]

        expect(campaign.places).to eq([place])
      end

      it 'keeps the actual data if the place already exists on the DB' do
        create(:place,
               name: 'Guilles place',
               formatted_address: 'api fmt address', zipcode: 44_332, route: '444 cc', street_number: 'Calle 2',
               city: 'Paraiso', state: 'Cartago', country: 'CR', lonlat: 'POINT(-1.234 1.234)',
               place_id: '123', reference: 'XYZ'
        )

        expect_any_instance_of(GooglePlaces::Client).to receive(:spots).and_return([
          double(place_id: '123', name: 'Guilles place', reference: 'XYZ')])

        expect_any_instance_of(described_class).to receive(:open).and_return(
          double(read: ActiveSupport::JSON.encode('results' => [{
                                                    'geometry' => { 'location' => { 'lat' => '1.2322', lng: '-3.23455' } } }])))

        expect do
          xhr :post, 'create', area_id: area.id, add_new_place: true,
                               place: { name: "Guille's place", street_number: '123 st', route: 'xyz 321',
                                        city: 'Curridabat', state: 'San Jose', zipcode: '12345', country: 'CR' },
                               format: :js
        end.to_not change(Place, :count)

        place = Place.last
        expect(place.name).to eql 'Guilles place'
        expect(place.formatted_address).to eql 'api fmt address'
        expect(place.street_number).to eql 'Calle 2'
        expect(place.route).to eql '444 cc'
        expect(place.city).to eql 'Paraiso'
        expect(place.state).to eql 'Cartago'
        expect(place.zipcode).to eql '44332'
        expect(place.country).to eql 'CR'
        expect(place.place_id).to eql '123'
        expect(place.reference).to eql 'XYZ'
        expect(place.latitude).to eql 1.234
        expect(place.longitude).to eql -1.234

        expect(area.places).to eq([place])
      end
    end

    it 'adds a place to the campaing and clears the cache' do
      Kpi.create_global_kpis
      expect(Rails.cache).to receive(:delete).at_least(1).times.with("campaign_locations_#{campaign.id}")
      xhr :post, 'create', campaign_id: campaign.id, place: { reference: place.to_param }, format: :js
      expect(campaign.places).to include(place)
    end

    it 'validates the address' do
      expect do
        xhr :post, 'create', area_id: area.to_param, add_new_place: true, place: {
          name: "Guille's place", street_number: '123 st', route: 'QWERTY 321',
          city: 'YYYYYYYYYY', state: 'XXXXXXXXXXX', zipcode: '12345', country: 'CR' }, format: :js
      end.to_not change(Place, :count)
      expect(assigns(:place).errors[:base]).to include("The entered address doesn't seems to be valid")
      expect(response).to render_template('_new_place_form')
    end

    it 'should render the form for new place if the place was not selected from the autocomplete for an area' do
      expect do
        xhr :post, 'create', area_id: area.to_param, place: { reference: '' },
                             reference_display_name: 'blah blah blah', format: :js
      end.to_not change(Place, :count)
      expect(response).to be_success
      expect(response).to render_template('places/_new_place_form')
      expect(response).to render_template('places/new_place')
    end

    it 'should render the form for new place if the place was not selected from the autocomplete for a campaign' do
      expect do
        xhr :post, 'create', campaign_id: campaign.to_param, place: { reference: '' },
                             reference_display_name: 'blah blah blah', format: :js
      end.to_not change(Place, :count)
      expect(response).to be_success
      expect(response).to render_template('places/_new_place_form')
      expect(response).to render_template('places/new_place')
    end

    it 'should render the form for new place if the place was not selected from the autocomplete for a company user' do
      expect do
        xhr :post, 'create', company_user_id: company_user.to_param, place: { reference: '' },
                             reference_display_name: 'blah blah blah', format: :js
      end.to_not change(Place, :count)
      expect(response).to be_success
      expect(response).to render_template('places/_new_place_form')
      expect(response).to render_template('places/new_place')
    end
  end

  describe "GET 'new'" do
    it 'returns http success' do
      xhr :get, 'new', area_id: area.id, format: :js
      expect(response).to be_success
      expect(response).to render_template('new')
      expect(response).to render_template('_form')
    end
  end

  describe "DELETE 'destroy'" do
    it 'should delete the link within the area and the place' do
      area.places << place
      expect do
        expect do
          delete 'destroy', area_id: area.to_param, id: place.id, format: :js
          expect(response).to be_success
        end.to change(Placeable, :count).by(-1)
      end.to_not change(Area, :count)
    end

    it 'should delete the link within the company user and the place' do
      company_user.places << place
      expect do
        expect do
          delete 'destroy', company_user_id: company_user.to_param, id: place.id, format: :js
          expect(response).to be_success
        end.to change(Placeable, :count).by(-1)
      end.to_not change(CompanyUser, :count)
    end

    it 'should delete the link within the campaign and the place' do
      expect(Rails.cache).to receive(:delete).at_least(1).times.with("campaign_locations_#{campaign.id}")
      campaign.places << place
      expect do
        expect do
          delete 'destroy', campaign_id: campaign.to_param, id: place.id, format: :js
          expect(response).to be_success
        end.to change(Placeable, :count).by(-1)
      end.to_not change(Campaign, :count)
    end

    it 'should call the method update_common_denominators' do
      area.places << place

      expect_any_instance_of(Area).to receive(:update_common_denominators)
      expect do
        expect do
          delete 'destroy', area_id: area.to_param, id: place.id, format: :js
          expect(response).to be_success
        end.to change(Placeable, :count).by(-1)
      end.to_not change(Area, :count)
    end
  end

  describe 'should allow to edit places' do
    let(:venue) { create(:venue, company: company, place_price_level: '4', web_address: 'http://www.test.com', place: create(:place, name: 'test 1', is_custom_place: true, reference: nil)) }

    it 'returns http success' do
      expect do
        expect do
          expect do
            xhr :patch, 'update', id: venue.place.id, add_new_place: 'false', place: { venues_attributes: { '0' =>
                { id: venue.id, web_address: 'www.guilles.com', place_price_level: '3', phone_number: '(404) 65652114',
                  company_id: company.id, hours_fields_attributes: {
                    '0' => { day: '1', hour_open: '0600', hour_close: '0000', '_destroy' => 'false' }
                  } } } }, format: :js
          end.to change(Place, :count).by(1)
        end.to change(Venue, :count).by(1)
      end.to change(HoursField, :count).by(1)
      place = Place.last
      venue = Venue.last
      expect(place.name).to eql 'test 1'
      expect(place.street_number).to eql '11'
      expect(place.route).to eql 'Main St.'
      expect(place.city).to eql 'New York City'
      expect(place.state).to eql 'NY'
      expect(place.zipcode).to eql '12345'
      expect(place.country).to eql 'US'
      expect(venue.opening_hours.count).to eql 1
      expect(venue.website).to eql 'http://www.guilles.com'
      expect(venue.phone_number).to eql '(404) 65652114'
      expect(venue.price_level).to eql 3
    end
  end

  describe 'should allow to edit places remove hours' do
    let(:venue) { create(:venue, company: company, web_address: 'http://www.test.com', place: create(:place, name: 'test 2', is_custom_place: true, reference: nil)) }

    it 'returns http success' do
      hours1 = create(:hours_field, day: '0', hour_open: '1200', hour_close: '0100', venue: venue)
      hours2 = create(:hours_field, day: '1', hour_open: '1600', hour_close: '0100', venue: venue)
      expect do
        expect do
          expect do
            xhr :patch, 'update', id: venue.place.id, add_new_place: 'false', place: { venues_attributes: { '0' =>
                { id: venue.id, web_address: 'www.guilles.com', company_id: company.id, hours_fields_attributes: {
                  '0' => { id: hours1.id, day: '0', hour_open: '0600', hour_close: '0000', '_destroy' => 'true' },
                  '1' => { id: hours2.id, day: '1', hour_open: '0600', hour_close: '0000', '_destroy' => 'false' }
                } } } }, format: :js
          end.to change(Place, :count).by(0)
        end.to change(Venue, :count).by(0)
      end.to change(HoursField, :count).by(-1)
      place = Place.last
      venue = Venue.last
      expect(place.name).to eql 'test 2'
      expect(place.street_number).to eql '11'
      expect(place.route).to eql 'Main St.'
      expect(place.city).to eql 'New York City'
      expect(place.state).to eql 'NY'
      expect(place.zipcode).to eql '12345'
      expect(place.country).to eql 'US'
      expect(venue.website).to eql 'http://www.guilles.com'
    end
  end
end
