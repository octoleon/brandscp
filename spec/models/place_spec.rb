# == Schema Information
#
# Table name: places
#
#  id                     :integer          not null, primary key
#  name                   :string(255)
#  reference              :string(400)
#  place_id               :string(200)
#  types_old              :string(255)
#  formatted_address      :string(255)
#  street_number          :string(255)
#  route                  :string(255)
#  zipcode                :string(255)
#  city                   :string(255)
#  state                  :string(255)
#  country                :string(255)
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  administrative_level_1 :string(255)
#  administrative_level_2 :string(255)
#  td_linx_code           :string(255)
#  location_id            :integer
#  is_location            :boolean
#  price_level            :integer
#  phone_number           :string(255)
#  neighborhoods          :string(255)      is an Array
#  lonlat                 :geography({:srid point, 4326
#  td_linx_confidence     :integer
#  merged_with_place_id   :integer
#  types                  :string(255)      is an Array
#

require 'rails_helper'

describe Place, type: :model do

  it { is_expected.to validate_presence_of(:place_id) }
  it { is_expected.to validate_presence_of(:reference) }

  it { is_expected.to allow_value(%w(restaurant bar)).for(:types) }
  it { is_expected.to allow_value(['political']).for(:types) }

  it { is_expected.to_not allow_value(nil).for(:types) }
  it { is_expected.to_not allow_value(['foo']).for(:types) }
  it { is_expected.to_not allow_value(%w(foo bar)).for(:types) }

  it { is_expected.to allow_value(nil).for(:country) }
  it { is_expected.to allow_value('').for(:country) }
  it { is_expected.to allow_value('US').for(:country) }
  it { is_expected.to allow_value('CR').for(:country) }
  it { is_expected.to allow_value('CA').for(:country) }
  it { is_expected.not_to allow_value('ZZY').for(:country).with_message('is not valid') }
  it { is_expected.not_to allow_value('Costa Rica').for(:country).with_message('is not valid') }
  it { is_expected.not_to allow_value('United States').for(:country).with_message('is not valid') }

  describe 'fetch_place_data' do
    it 'should correctly assign the attributes returned by the api call' do
      place = described_class.new(reference: 'YXZ', place_id: '123')
      api_client = double(:google_places_client)
      expect(place).to receive(:client).at_least(:once).and_return(api_client)
      expect(api_client).to receive(:spot).with('YXZ').and_return(
        double(:spot,
               name: 'Rancho Grande',
               lat: '12.345678',
               lng: '-87.654321',
               formatted_address: '123 Mi Casa, Costa Rica',
               types: %w(bar establishment),
               address_components: [
                 { 'types' => ['country'], 'short_name' => 'CR', 'long_name' => 'Costa Rica' },
                 { 'types' => ['administrative_area_level_1'], 'short_name' => 'SJO', 'long_name' => 'San Jose' },
                 { 'types' => ['administrative_area_level_2'], 'short_name' => 'SJ2', 'long_name' => 'Example' },
                 { 'types' => ['locality'], 'short_name' => 'Curridabat', 'long_name' => 'Curridabat' },
                 { 'types' => ['postal_code'], 'short_name' => '12345', 'long_name' => '12345' },
                 { 'types' => ['street_number'], 'short_name' => '7', 'long_name' => '7' },
                 { 'types' => ['route'], 'short_name' => 'Calle Melancolia', 'long_name' => 'Calle Melancolia' }
               ]))
      expect(api_client).to receive(:spots).at_least(:once).and_return([])

      place.save
      place.reload
      expect(place.name).to eq('Rancho Grande')
      expect(place.latitude).to eq(12.345678)
      expect(place.longitude).to eq(-87.654321)
      expect(place.formatted_address).to eq('123 Mi Casa, Costa Rica')
      expect(place.types).to eq(%w(bar establishment))
      expect(place.country).to eq('CR')
      expect(place.city).to eq('Curridabat')
      expect(place.state).to eq('San Jose')
      expect(place.administrative_level_1).to eq('SJO')
      expect(place.administrative_level_2).to eq('SJ2')
      expect(place.zipcode).to eq('12345')
      expect(place.street_number).to eq('7')
      expect(place.route).to eq('Calle Melancolia')
    end

    it "should find out the correct state name if the API doesn't provide it" do
      place = described_class.new(reference: 'YXZ', place_id: '123')
      api_client = double(:google_places_client)
      expect(place).to receive(:client).at_least(:once).and_return(api_client)
      expect(api_client).to receive(:spot).with('YXZ').and_return(
        double(:spot,
               name: 'Shark\'s Cove',
               lat: '12.345678',
               lng: '-87.654321',
               formatted_address: '123 Mi Casa, Costa Rica',
               types: %w(bar establishment),
               address_components: [
                 { 'types' => ['country'], 'short_name' => 'US', 'long_name' => 'United States' },
                 { 'types' => ['administrative_area_level_1'], 'short_name' => 'CA', 'long_name' => 'CA' },
                 { 'types' => ['locality'], 'short_name' => 'Manhattan Beach', 'long_name' => 'Manhattan Beach' },
                 { 'types' => ['postal_code'], 'short_name' => '12345', 'long_name' => '12345' },
                 { 'types' => ['street_number'], 'short_name' => '7', 'long_name' => '7' },
                 { 'types' => ['route'], 'short_name' => 'Calle Melancolia', 'long_name' => 'Calle Melancolia' }
               ]))
      expect(api_client).to receive(:spots).at_least(:once).and_return([])
      place.save
      place.reload
      expect(place.name).to eq('Shark\'s Cove')
      expect(place.state).to eq('California')
      expect(place.administrative_level_1).to eq('CA')
      expect(place.administrative_level_2).to eq(nil)
    end
  end

  describe '#political_division' do
    it "should return the name in the locations if it's a sublocality" do
      sublocality = create(:place, name: 'Beverly Hills', types: ['sublocality'], route: nil,
                                   street_number: nil, city: 'Los Angeles', state: 'California',
                                   country: 'US')
      expect(described_class.political_division(sublocality)).to eq([
        'North America', 'United States', 'California', 'Los Angeles', 'Beverly Hills'
      ])
    end

    it 'should return the city in the locations' do
      bar = create(:place, route: '1st st', street_number: '12 sdfsd', city: 'Los Angeles',
                           state: 'California', country: 'US')
      expect(described_class.political_division(bar)).to eq([
        'North America', 'United States', 'California', 'Los Angeles'
      ])
    end

    it 'should return false if the place is a state and the are has cities of that state' do
      california = create(:place, types: ['locality'], route: nil, street_number: nil,
                                  city: nil, state: 'California', country: 'US')
      expect(described_class.political_division(california)).to eq([
        'North America', 'United States', 'California'
      ])
    end

    it 'returns nil if no place is given' do
      expect(described_class.political_division(nil)).to be_nil
    end
  end

  describe '#in_areas' do
    let(:company) { create(:company) }
    let(:campaign) { create(:campaign, company: company) }

    it 'should include events that are scheduled on the given places' do
      place_la = create(:place, country: 'US', state: 'California', city: 'Los Angeles')
      place_sf = create(:place, country: 'US', state: 'California', city: 'San Francisco')
      area_la = create(:area, company: company, place_ids: [place_la.id])
      area_sf = create(:area, company: company, place_ids: [place_sf.id])

      expect(described_class.in_areas([area_la])).to match_array [place_la]
      expect(described_class.in_areas([area_sf])).to match_array [place_sf]
      expect(described_class.in_areas([area_la, area_sf])).to match_array [place_la, place_sf]
    end

    it 'should include places that are located within the given scope if the place is a locality' do
      los_angeles = create(:city, name: 'Los Angeles', country: 'US', state: 'California')
      place_la = create(:place, country: 'US', state: 'California', city: 'Los Angeles')

      san_francisco = create(:city, name: 'San Francisco', country: 'US', state: 'California')
      place_sf = create(:place, country: 'US', state: 'California', city: 'San Francisco')

      area_la = create(:area, company: company, place_ids: [los_angeles.id])
      area_sf = create(:area, company: company, place_ids: [san_francisco.id])

      expect(described_class.in_areas([area_la])).to match_array [place_la, los_angeles]
      expect(described_class.in_areas([area_sf])).to match_array [place_sf, san_francisco]
      expect(described_class.in_areas([area_la, area_sf])).to match_array [place_la, los_angeles, place_sf, san_francisco]
    end
  end

  describe '#locations' do
    it 'returns only the continent and country' do
      country = create(:country, name: 'US')
      expect(country.locations.map(&:path)).to match_array([
        'north america',
        'north america/united states'
      ])
    end

    it 'returns the state, continent and country' do
      state = create(:state, name: 'California', country: 'US')
      expect(state.locations.map(&:path)).to match_array([
        'north america',
        'north america/united states',
        'north america/united states/california'
      ])
    end

    it 'returns the city, state, continent and country' do
      city = create(:city, name: 'Los Angeles', state: 'California', country: 'US')
      expect(city.locations.map(&:path)).to match_array([
        'north america',
        'north america/united states',
        'north america/united states/california',
        'north america/united states/california/los angeles'
      ])
    end

    it 'returns the sublocality, city, state, continent and country' do
      sublocality = create(:place, name: 'Beverly Hills', types: ['sublocality'], route: nil,
                                   street_number: nil, city: 'Los Angeles', state: 'California',
                                   country: 'US')
      expect(sublocality.locations.map(&:path)).to match_array([
        'north america',
        'north america/united states',
        'north america/united states/california',
        'north america/united states/california/los angeles',
        'north america/united states/california/los angeles/beverly hills'
      ])
    end
  end

  describe '#td_linx_match' do
    before do
      TdLinx::Processor.drop_tdlinx_codes_table
      TdLinx::Processor.create_tdlinx_codes_table
      ActiveRecord::Base.connection.execute("INSERT INTO tdlinx_codes VALUES
        ('0000071','Big Es Supermarket','11 Union St','Easthampton','MA','01027'),
        ('0000072','Valley Farms Store','128 Northampton St','Easthampton','MA','01027')")
    end

    it 'returns the correct value with a confidence of 10' do
      place = create(:place, name: 'Big Es Supermarket', street_number: '11',
                             route: 'Union St', zipcode: '01027', state: 'Massachusetts')
      expect(described_class.td_linx_match(place.id, place.state_code)).to eql(
        'code' => '0000071', 'name' => 'Big Es Supermarket', 'street' => '11 Union St',
        'city' => 'Easthampton', 'state' => 'MA', 'zipcode' => '01027', 'confidence' => '10')
    end

    it 'returns the correct value with a confidence of 10 if the first letters match' do
      place = create(:place, name: 'Big Es', street_number: '11',
                             route: 'Un', zipcode: '01027', state: 'Massachusetts')
      expect(described_class.td_linx_match(place.id, place.state_code)).to eql(
        'code' => '0000071', 'name' => 'Big Es Supermarket', 'street' => '11 Union St',
        'city' => 'Easthampton', 'state' => 'MA', 'zipcode' => '01027', 'confidence' => '10')
    end

    it 'returns the correct value with a confidence of 10 ignoring removing "the" at the begining of the name' do
      place = create(:place, name: 'The Big Es Supermarket', street_number: '11',
                             route: 'Union St', zipcode: '01027', state: 'Massachusetts')
      expect(described_class.td_linx_match(place.id, place.state_code)).to eql(
        'code' => '0000071', 'name' => 'Big Es Supermarket', 'street' => '11 Union St',
        'city' => 'Easthampton', 'state' => 'MA', 'zipcode' => '01027', 'confidence' => '10')
    end

    it 'is case unsensitive' do
      place = create(:place, name: 'BIG ES Supermarket', street_number: '11',
                             route: 'union St', zipcode: '01027', state: 'Massachusetts')
      expect(described_class.td_linx_match(place.id, place.state_code)).to eql(
        'code' => '0000071', 'name' => 'Big Es Supermarket', 'street' => '11 Union St',
        'city' => 'Easthampton', 'state' => 'MA', 'zipcode' => '01027', 'confidence' => '10')
    end

    it 'returns the correct value with a confidence of 5 if the name is slightly different'  do
      place = create(:place, name: 'Supermarket Big ES', street_number: '11',
                             route: ' Union', zipcode: '01027', state: 'Massachusetts')
      expect(described_class.td_linx_match(place.id, place.state_code)).to eql(
        'code' => '0000071', 'name' => 'Big Es Supermarket', 'street' => '11 Union St',
        'city' => 'Easthampton', 'state' => 'MA', 'zipcode' => '01027', 'confidence' => '5')
    end

    it 'returns the correct value with a confidence of 5 if the first letters of the address match but its slightly different' do
      place = create(:place, name: 'Supermarket Big Es', street_number: '11',
                             route: 'Union Street N', zipcode: '01027', state: 'Massachusetts')
      expect(described_class.td_linx_match(place.id, place.state_code)).to eql(
        'code' => '0000071', 'name' => 'Big Es Supermarket', 'street' => '11 Union St',
        'city' => 'Easthampton', 'state' => 'MA', 'zipcode' => '01027', 'confidence' => '5')
    end

    it 'returns the correct value with a confidence of 1 if the street doesn\'t match'  do
      place = create(:place, name: 'Big Es Supermarket', street_number: '12',
                             route: 'Union St', zipcode: '01027', state: 'Massachusetts')
      expect(described_class.td_linx_match(place.id, place.state_code)).to eql(
        'code' => '0000071', 'name' => 'Big Es Supermarket', 'street' => '11 Union St',
        'city' => 'Easthampton', 'state' => 'MA', 'zipcode' => '01027', 'confidence' => '1')
    end

    it 'returns the correct value with a confidence of 1 if only the first two chars of the zipcode match'  do
      place = create(:place, name: 'Big Es Supermarket', street_number: '11',
                             route: 'Union St', zipcode: '01345', state: 'Massachusetts')
      expect(described_class.td_linx_match(place.id, place.state_code)).to eql(
        'code' => '0000071', 'name' => 'Big Es Supermarket', 'street' => '11 Union St',
        'city' => 'Easthampton', 'state' => 'MA', 'zipcode' => '01027', 'confidence' => '1')
    end

    it 'returns the correct value with a confidence of 1 if the first letters match its in other state' do
      place = create(:place, name: 'Big Es Supermarket', street_number: '11',
                             route: 'Union Street', zipcode: '01020', state: 'California')
      expect(described_class.td_linx_match(place.id, place.state_code)).to eql(
        'code' => '0000071', 'name' => 'Big Es Supermarket', 'street' => '11 Union St',
        'city' => 'Easthampton', 'state' => 'MA', 'zipcode' => '01027', 'confidence' => '1')
    end
  end

  describe '#find_place' do
    let!(:place) do
      create(:place, name: 'Benitos Bar', city: 'Los Angeles', state: 'California',
                     street_number: '123 st', route: 'Maria nw', zipcode: '11223')
    end

    it 'returns the place that exactly match the search params' do
      expect(
        described_class.find_place(
          name: 'Benitos Bar', state: 'California',
          street: '123 st Maria nw', zipcode: '11223'
        )
      ).to eql([
        ['10', '1', place.id.to_s],
        ['5', '1', place.id.to_s],
        ['1', '1', place.id.to_s]])
    end

    it 'returns the place that exactly match the search params without a zipcode' do
      expect(
        described_class.find_place(
          name: 'Benitos Bar', city: 'Los Angeles', state: 'California',
          street: '123 st Maria nw', zipcode: nil
        )
      ).to eql [["1", "1", place.id.to_s]]
    end

    it 'returns the place that have a similar name with the same address' do
      expect(
        described_class.find_place(
          name: 'Benito Bar', state: 'California',
          street: '123 st Maria nw', zipcode: nil
        )
      ).to eql([["1", "0.75", place.id.to_s]])

      expect(
        described_class.find_place(
          name: 'BENITOSS Bar', state: 'California',
          street: '123 st Maria nw', zipcode: nil
        )
      ).to eql([["1", "0.769231", place.id.to_s]])
    end

    it 'returns the place that have a similar name with the same address written in different ways' do
      expect(
        described_class.find_place(
          name: 'Benito Bar', state: 'California',
          street: '123 street Maria nw', zipcode: nil
        )
      ).to eql([["1", "0.75", place.id.to_s]])

      expect(
        described_class.find_place(
          name: 'BENITOSS Bar', state: 'California',
          street: '123 st Maria Northweast', zipcode: nil
        )
      ).to eql([["1", "0.769231", place.id.to_s]])

      expect(
        described_class.find_place(
          name: 'BENITOSS Bar', state: 'California',
          street: '123 street Maria Northweast', zipcode: nil
        )
      ).to eql([["1", "0.769231", place.id.to_s]])

      expect(
        described_class.find_place(
          name: 'BENITOSS Bar', state: 'California',
          street: '1234 street Maria Northweast', zipcode: nil
        )
      ).to eql([["1", "0.769231", place.id.to_s]])
    end

    it 'does not returns the place that have a different name with the same address' do
      expect(
        described_class.find_place(
          name: 'Mercedes Bar', city: 'Los Angeles', state: 'California',
          street: '123 st Maria nw', zipcode: nil
        )
      ).to be_empty
    end
  end

  describe '#in_campaign_scope' do
    let(:company) { create(:company) }
    let(:campaign) { create(:campaign, company: company) }

    it 'includes only places within the campaign areas' do
      place_la = create(:place, country: 'US', state: 'California', city: 'Los Angeles')
      place_sf = create(:place, country: 'US', state: 'California', city: 'San Francisco')
      city_la = create(:place, country: 'US', state: 'California', city: 'Los Angeles', types: ['locality'])
      city_sf = create(:place, country: 'US', state: 'California', city: 'San Francisco', types: ['locality'])

      area_la = create(:area, company: company)
      area_sf = create(:area, company: company)

      campaign.areas << [area_la, area_sf]

      area_la.places << [city_la, city_sf]

      expect(described_class.in_campaign_scope(campaign)).to match_array [place_la, place_sf, city_la, city_sf]
    end

    it 'excludes places that are in places that were excluded from the campaign' do
      place_la = create(:place, country: 'US', state: 'California', city: 'Los Angeles')

      place_sf = create(:place, country: 'US', state: 'California', city: 'San Francisco')

      area_la = create(:area, company: company)
      area_sf = create(:area, company: company)

      area_la.places << place_la
      area_sf.places << place_sf

      # Associate areas to campaigns
      create(:areas_campaign, area: area_la, campaign: campaign, exclusions: [place_la.id])
      create(:areas_campaign, area: area_sf, campaign: campaign)

      expect(described_class.in_campaign_scope(campaign)).to match_array [place_sf]
    end

    it 'excludes places that are in places inside an excluded city' do
      place_la = create(:place, country: 'US', state: 'California', city: 'Los Angeles')

      city_la = create(:city, name: 'Los Angeles', country: 'US', state: 'California')
      area_la = create(:area, company: company)

      area_la.places << city_la

      area_campaign_la = create(:areas_campaign, area: area_la, campaign: campaign)
      expect(described_class.in_campaign_scope(campaign)).to match_array [place_la, city_la]

      area_campaign_la.update_attribute :exclusions, [city_la.id]
      expect(described_class.in_campaign_scope(campaign)).to be_empty
    end

    it 'includes places that are inside an included city' do
      campaign2 = create(:campaign, company: company)
      place_la = create(:place, country: 'US', state: 'California', city: 'Los Angeles')
      place_sf = create(:place, country: 'US', state: 'California', city: 'San Francisco')

      city_la = create(:city, name: 'Los Angeles', country: 'US', state: 'California')
      city_sf = create(:city, name: 'San Francisco', country: 'US', state: 'California')
      area_la = create(:area, company: company)
      area_sf = create(:area, company: company)
      area_sf.places << city_sf

      area_campaign_la = create(:areas_campaign, area: area_la, campaign: campaign)
      create(:areas_campaign, area: area_sf, campaign: campaign)
      create(:areas_campaign, area: area_la, campaign: campaign2)

      expect(described_class.in_campaign_scope(campaign)).to match_array [place_sf, city_sf]

      area_campaign_la.update_attribute :inclusions, [city_la.id]
      expect(described_class.in_campaign_scope(campaign)).to match_array [place_sf, place_la, city_la, city_sf]
    end

    it 'includes places that are inside a city added directly to the campaign' do
      place_la = create(:place, country: 'US', state: 'California', city: 'Los Angeles')
      city_la = create(:city, name: 'Los Angeles', country: 'US', state: 'California')

      campaign.places << city_la

      expect(described_class.in_campaign_scope(campaign)).to match_array [place_la, city_la]
    end
  end

  describe '#merge' do
    let(:campaign) { create(:campaign) }
    let(:place1) do
      create(:place, route: '1st st', street_number: '12 Street', city: 'Los Angeles',
                                  state: 'California', country: 'US')
    end
    let(:place2) do
      create(:place, route: '2st st', street_number: '22 Street', city: 'Los Angeles',
                                  state: 'California', country: 'US')
    end
    let!(:venue1) { create(:venue, company_id: campaign.company_id, place: place1) }
    let!(:venue2) { create(:venue, company_id: campaign.company_id, place: place2) }
    let!(:event) do
      create(:event, place_id: place1.id, company_id: campaign.company_id, start_date: '01/23/2019',
                                 end_date: '01/23/2019', start_time: '8:00am', end_time: '11:00am')
    end
    let(:area) {  create(:area, company_id: campaign.company_id) }

    before do
      area.places << place1
    end

    it 'should merge venues' do
      expect do
        place2.merge(place1)
      end.to change(Venue, :count).by(-1)

      expect { Venue.find(venue1.id) }.to raise_error(ActiveRecord::RecordNotFound)

      event.reload
      expect(event.place_id).to eq(place2.id)

      expect(place1.merged_with_place_id).to eq(place2.id)
      expect(Placeable.first.place_id).to eq(place2.id)
    end

    it 'should not merge venues when it is already merged' do
      place2.update_attribute :merged_with_place_id, 3

      expect { place2.merge(place1) }.to raise_error(RuntimeError)

      expect(Venue.count).to eq(2)

      event.reload
      expect(event.place_id).to eq(place1.id)

      expect(place1.merged_with_place_id).to eq(nil)
      expect(Placeable.first.place_id).to eq(place1.id)
    end

    it 'should not merge a place with itself' do
      expect { place2.merge(place2) }.to raise_error(RuntimeError)

      expect(Venue.count).to eq(2)

      event.reload
      expect(event.place_id).to eq(place1.id)

      expect(place1.merged_with_place_id).to eq(nil)
      expect(Placeable.first.place_id).to eq(place1.id)
    end
  end

  describe 'Complete and fix place data on place save' do
    it 'normalize city and neighborhoods names, and update locations data' do
      place = create(:place, name: 'Beverly Hills', types: %w(locality political), route: nil,
                             street_number: nil, city: 'St Louis', state: 'Missouri',
                             country: 'US', neighborhoods: ['St. Pablo'])

      place.save
      expect(place.city).to eq('Saint Louis')
      expect(place.neighborhoods).to eq(['Saint Pablo'])
      expect(place.is_location).to eq(true)
      expect(place.location.path).to eq('north america/united states/missouri/saint louis/saint pablo')
      expect(place.locations.map(&:path)).to match_array([
        'north america',
        'north america/united states',
        'north america/united states/missouri',
        'north america/united states/missouri/saint louis',
        'north america/united states/missouri/saint louis/saint pablo'
      ])
    end
  end
end
