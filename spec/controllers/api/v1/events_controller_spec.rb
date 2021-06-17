require 'rails_helper'

describe Api::V1::EventsController, type: :controller do
  let(:user) { sign_in_as_user }
  let(:company) { user.company_users.first.company }
  let(:campaign) { create(:campaign, company: company) }
  let(:place) { create(:place) }

  before { set_api_authentication_headers user, company }

  describe "GET 'index'", search: true do
    it 'return a list of events', :show_in_doc do
      create_list(:event, 3, company: company, campaign: campaign, place: place)
      Sunspot.commit

      get :index, campaign: [campaign.id], place: [place.id], format: :json
      expect(response).to be_success
      result = JSON.parse(response.body)

      expect(result['results'].count).to eq(3)
      expect(result['total']).to eq(3)
      expect(result['page']).to eq(1)
      expect(result['filters']).to eq([
        { 'label' => campaign.name, 'name' => "campaign:#{campaign.id}", 'expandible' => false },
        { 'label' => place.name, 'name' => "place:#{place.id}", 'expandible' => false }])
      expect(result['results'].first.keys).to match_array(%w(id start_date start_time end_date end_time status phases event_status campaign place))
    end

    it 'sencond page returns empty results' do
      create_list(:event, 3, company: company, campaign: campaign, place: place)
      Sunspot.commit

      get :index, page: 2, format: :json
      expect(response).to be_success
      result = JSON.parse(response.body)

      expect(result['results'].count).to eq(0)
      expect(result['total']).to eq(3)
      expect(result['page']).to eq(2)
      expect(result['results']).to be_empty
    end

    it 'return a list of events filtered by campaign id' do
      other_campaign = create(:campaign, company: company)
      create_list(:event, 3, company: company, campaign: campaign, place: place)
      create_list(:event, 3, company: company, campaign: other_campaign, place: place)
      Sunspot.commit

      get :index, campaign: [campaign.id], format: :json
      expect(response).to be_success
      result = JSON.parse(response.body)

      expect(result['results'].count).to eq(3)
    end

    it 'return a list of events from notification link' do
      company_user = user.company_users.first
      event1 = create(:event, company: company, campaign: campaign, place: place)
      event2 = create(:event, company: company, campaign: campaign, place: place)
      event1.users << company_user
      event2.users << company_user
      Sunspot.commit

      expect do
        get :index, campaign: [campaign.id], place: [place.id], new_at: 123_456, format: :json
      end.to change(Notification, :count).by(-2)
      expect(response).to be_success
      result = JSON.parse(response.body)

      expect(result['results'].count).to eq(2)
      expect(result['total']).to eq(2)
      expect(result['page']).to eq(1)
      expect(result['filters']).to eq([
        { 'label' => campaign.name, 'name' => "campaign:#{campaign.id}", 'expandible' => false },
        { 'label' => place.name, 'name' => "place:#{place.id}", 'expandible' => false }])
      expect(result['results'].first.keys).to match_array(%w(id start_date start_time end_date end_time status phases event_status campaign place))
    end
  end

  describe "GET 'requiring_attention'", search: true do
    it 'returns a list of events late, due and today events', :show_in_doc do
      campaign.modules = { 'expenses' => {}, 'comments' => {}, 'photos' => {} }
      event1 = create(:late_event, campaign: campaign, place: place)
      event2 = create(:due_event, campaign: campaign, place: place)
      event3 = create(:event, start_date: Time.zone.now.to_s(:slashes),
                              end_date: Time.zone.now.to_s(:slashes),
                              campaign: campaign, place: place)

      create(:approved_event, campaign: campaign, place: place)
      Sunspot.commit

      get :requiring_attention, format: :json
      expect(response).to be_success
      expect(json.count).to eq(3)
      expect(json.first.keys).to match_array(%w(
        id start_date start_time end_date end_time status phases event_status
        campaign place))

      expect(json.map { |e| e['id'] }).to eql [event1.id, event2.id, event3.id]
    end
  end

  describe "GET 'show'" do
    let(:event) { create(:event, campaign: campaign, place: place) }
    let(:place) { create(:place, state: 'New York') }

    it 'returns the event info', :show_in_doc do
      event.users << user.company_users.first
      expect do
        get :show, id: event.to_param, format: :json
      end.to change(Notification, :count).by(-1)
      expect(response).to be_success
      expect(json.keys).to eq(%w(
        id start_date start_time end_date end_time status description phases event_status
        rejected_info have_data actions tasks_late_count tasks_due_today_count place campaign))
      expect(json['place']['state']).to eq('NY')
      expect(json['place'].keys).to eq(%w(
        id venue_id state name latitude longitude formatted_address
        country state_name city zipcode))
      expect(json['campaign'].keys).to eq(%w(
        id name enabled_modules modules))
    end
  end

  describe "GET 'status_facets'", search: true do
    it 'return the facets for the search', :show_in_doc do
      create(:approved_event, company: company, campaign: campaign, place: place)
      create(:rejected_event, company: company, campaign: campaign, place: place)
      create(:submitted_event, company: company, campaign: campaign, place: place)
      create(:late_event, company: company, campaign: campaign, place: place)
      create(:due_event, company: company, campaign: campaign, place: place)

      # Make sure custom filters are not returned
      create(:custom_filter, owner: company, apply_to: 'events')

      Sunspot.commit

      get :status_facets, format: :json
      expect(response).to be_success
      result = JSON.parse(response.body)

      expect(result['facets'].map { |f| f['label'] }).to match_array(
        %w(Approved Due Late Rejected Submitted))

      expect(
        result['facets'].map { |i| [i['label'], i['count']] }).to match_array([
          ['Late', 1], ['Due', 1], ['Submitted', 1],
          ['Rejected', 1], ['Approved', 1]])
    end
  end

  describe "POST 'create'" do
    let(:campaign) { create(:campaign, company: company) }
    let(:place) { create(:place) }
    it "should assign current_user's company_id to the new event" do
      expect do
        post 'create', event: { campaign_id: campaign.id, start_date: '05/21/2020', start_time: '12:00pm',
                                end_date: '05/22/2020', end_time: '01:00pm', place_id: place.id }, format: :json
      end.to change(Event, :count).by(1)
      expect(assigns(:event).company_id).to eq(company.id)
    end

    it 'should create the event with the correct dates' do
      expect do
        post 'create', event: { campaign_id: campaign.id, start_date: '05/21/2020', start_time: '12:00pm',
                                end_date: '05/21/2020', end_time: '01:00pm', place_id: place.id }, format: :json
      end.to change(Event, :count).by(1)
      new_event = Event.last
      expect(new_event.campaign_id).to eq(campaign.id)
      expect(new_event.start_at).to eq(Time.zone.parse('2020/05/21 12:00pm'))
      expect(new_event.end_at).to eq(Time.zone.parse('2020/05/21 01:00pm'))
      expect(new_event.place_id).to eq(place.id)
      expect(new_event.promo_hours).to eq(1)
    end

    it 'should not create the event when dates are not valid for a visit' do
      visit = create(:brand_ambassadors_visit, company: company,
                     start_date: '11/09/2014', end_date: '11/11/2014', campaign: campaign)
      expect do
        post 'create', event: { campaign_id: campaign.id, start_date: '11/09/2014', start_time: '12:00pm',
                                end_date: '11/15/2014', end_time: '01:00pm', place_id: place.id, visit_id: visit.id }, format: :json
      end.to change(Event, :count).by(0)
      expect(response.response_code).to eq(422)
      result = JSON.parse(response.body)
      expect(result['end_date']).to include('should be before 11/12/2014')
    end

    it 'should create the event when dates are valid for a visit' do
      visit = create(:brand_ambassadors_visit, company: company,
                     start_date: '11/09/2014', end_date: '11/11/2014', campaign: campaign)
      expect do
        post 'create', event: { campaign_id: campaign.id, start_date: '11/10/2014', start_time: '12:00pm',
                                end_date: '11/10/2014', end_time: '01:00pm', place_id: place.id, visit_id: visit.id }, format: :json
      end.to change(Event, :count).by(1)
      new_event = Event.last
      expect(new_event.campaign_id).to eq(campaign.id)
      expect(new_event.start_at).to eq(Time.zone.parse('2014/11/10 12:00pm'))
      expect(new_event.end_at).to eq(Time.zone.parse('2014/11/10 01:00pm'))
      expect(new_event.place_id).to eq(place.id)
      expect(new_event.promo_hours).to eq(1)
    end
  end

  describe "PUT 'update'", :show_in_doc do
    let(:campaign) { create(:campaign, company: company) }
    let(:event) { create(:event, company: company, campaign: campaign) }

    it 'must update the event attributes' do
      new_campaign = create(:campaign, company: company)
      put 'update', id: event.to_param, event: {
        campaign_id: new_campaign.id,
        start_date: '05/21/2020', start_time: '12:00pm', end_date: '05/22/2020', end_time: '01:00pm',
        place_id: place.id, description: 'this is the test description'
      }, format: :json
      expect(assigns(:event)).to eq(event)
      expect(response).to be_success
      event.reload
      expect(event.campaign_id).to eq(new_campaign.id)
      expect(event.start_at).to eq(Time.zone.parse('2020-05-21 12:00:00'))
      expect(event.end_at).to eq(Time.zone.parse('2020-05-22 13:00:00'))
      expect(event.place_id).to eq(place.id)
      expect(event.promo_hours.to_i).to eq(25)
      expect(event.description).to eq('this is the test description')
    end

    it 'must deactivate the event' do
      put 'update', id: event.to_param, event: { active: 'false' }, format: :json
      expect(assigns(:event)).to eq(event)
      expect(response).to be_success
      event.reload
      expect(event.active).to eq(false)
    end

    it 'must update the event attributes' do
      place = create(:place)
      put 'update', id: event.to_param, partial: 'event_data', event: { campaign_id: create(:campaign, company: company).to_param, start_date: '05/21/2020', start_time: '12:00pm', end_date: '05/22/2020', end_time: '01:00pm', place_id: place.id }, format: :json
      expect(assigns(:event)).to eq(event)
      expect(response).to be_success
    end

    it 'must update the event results' do
      Kpi.create_global_kpis
      campaign.assign_all_global_kpis
      result = event.result_for_kpi(Kpi.impressions)
      result.value = 321
      event.save

      put 'update', id: event.to_param, event: {
        results_attributes: [{ id: result.id.to_s, value: '987' }]
      }, format: :json
      result.reload
      expect(result.value).to eq('987')
    end

    it 'accepts composed results for event results' do
      Kpi.create_global_kpis
      campaign.assign_all_global_kpis
      gender_result = event.result_for_kpi(Kpi.gender)
      gender_result.value = {
        Kpi.gender.kpis_segments.first.id => 10,
        Kpi.gender.kpis_segments.last.id => 90
      }
      event.save

      put 'update', id: event.to_param, event: {
        results_attributes: [{
          id: gender_result.id.to_s,
          value: {
            Kpi.gender.kpis_segments.first.id.to_s => 50,
            Kpi.gender.kpis_segments.last.id.to_s => 50
          } }]
      }, format: :json
      expect(response.code).to eql '200'
      expect(gender_result.reload.value).to eq(
        Kpi.gender.kpis_segments.first.id.to_s => '50',
        Kpi.gender.kpis_segments.last.id.to_s => '50')
    end

    it 'returns an error if the value is invalid' do
      Kpi.create_global_kpis
      campaign.assign_all_global_kpis
      gender_result = event.result_for_kpi(Kpi.gender)
      gender_result.value = {
        Kpi.gender.kpis_segments.first.id => 10,
        Kpi.gender.kpis_segments.last.id => 90
      }
      event.save

      event.result_for_kpi(Kpi.age)

      put 'update', id: event.to_param, event: {
        results_attributes: [{
          id: gender_result.id.to_s,
          value: {
            Kpi.gender.kpis_segments.first.id.to_s => 5,
            Kpi.gender.kpis_segments.last.id.to_s => 5
          } }]
      }, format: :json
      expect(response.code).to eql '422'
      errors = JSON.parse(response.body)
      expect(errors).to eql('results.value' => ['is invalid'])
    end
  end

  describe "PUT 'submit'" do
    let(:event) { create(:event, campaign: campaign) }

    it 'should submit event' do
      expect do
        put 'submit', id: event.to_param, format: :json
        expect(response).to be_success
        event.reload
      end.to change(event, :submitted?).to(true)
    end

    it 'should not allow to submit the event if the event data is not valid' do
      create(:form_field_number, fieldable: campaign, required: true)
      expect do
        put 'submit', id: event.to_param, format: :json
        expect(response.response_code).to eq(422)
        event.reload
      end.to_not change(event, :submitted?)
    end
  end

  describe "PUT 'approve'" do
    let(:event) { create(:submitted_event, active: true, company: company) }

    it 'should approve event' do
      expect do
        put 'approve', id: event.to_param, format: :json
        expect(response).to be_success
        event.reload
      end.to change(event, :approved?).to(true)
    end
  end

  describe "PUT 'reject'" do
    let(:event) { create(:submitted_event, active: true, company: company) }

    it 'should reject event' do
      expect do
        put 'reject', id: event.to_param, reason: 'blah blah blah', format: :json
        expect(response).to be_success
        event.reload
      end.to change(event, :rejected?).to(true)
      expect(event.reject_reason).to eq('blah blah blah')
    end
  end

  describe "GET 'results'" do
    let(:campaign) { create(:campaign, company: company) }
    let(:event) { create(:event, company: company, campaign: campaign) }

    it "should return an empty array if the campaign doesn't have any fields" do
      get 'results', id: event.to_param, format: :json
      fields = JSON.parse(response.body)
      expect(response).to be_success
      expect(fields).to eq([])
    end

    it 'should return the stored values within the fields' do
      kpi = create(:kpi, name: '# of cats', kpi_type: 'number')
      campaign.add_kpi kpi
      result = event.result_for_kpi(kpi)
      result.value = 321
      event.save
      get 'results', id: event.to_param, format: :json

      groups = JSON.parse(response.body)
      expect(response).to be_success
      expect(groups.first['fields'].first).to include(
        'id' => result.id,
        'name' => '# of cats',
        'type' => 'FormField::Number',
        'value' => 321
      )
      expect(groups.first['fields'].first.keys).to_not include('segments')
    end

    it 'should return the segments for count fields' do
      kpi = create(:kpi, name: 'Are you tall?', kpi_type: 'count', description: 'some description to show',
                         kpis_segments: [
                           create(:kpis_segment, text: 'Yes'), create(:kpis_segment, text: 'No')
                         ])
      campaign.add_kpi kpi
      segments = kpi.kpis_segments
      result = event.result_for_kpi(kpi)
      result.value = segments.first.id
      event.save

      get 'results', id: event.to_param, format: :json
      groups = JSON.parse(response.body)
      expect(groups.first['fields'].first).to include(
          'id' => result.id,
          'name' => 'Are you tall?',
          'type' => 'FormField::Dropdown',
          'value' => "#{segments.first.id}",
          'description' => 'some description to show',
          'segments' => [
            { 'id' => segments.first.id, 'text' => 'Yes', 'value' => true, 'goal' => nil },
            { 'id' => segments.last.id, 'text' => 'No', 'value' => false, 'goal' => nil }
          ]
        )
    end

    it 'should return the percentage fields as one single field' do
      kpi = create(:kpi, name: 'Age', kpi_type: 'percentage',
          kpis_segments: [
            seg1 = create(:kpis_segment, text: 'Uno'),
            seg2 = create(:kpis_segment, text: 'Dos')
          ]
      )
      campaign.add_kpi kpi
      result = event.result_for_kpi(kpi)
      event.save

      get 'results', id: event.to_param, format: :json
      groups = JSON.parse(response.body)
      expect(groups.first['fields'].first).to include(
          'name' => 'Age',
          'id' => result.id,
          'type' => 'FormField::Percentage',
          'segments' => [
            { 'id' => seg1.id, 'text' => 'Uno', 'value' => nil, 'goal' => nil },
            { 'id' => seg2.id, 'text' => 'Dos', 'value' => nil, 'goal' => nil }
          ]
        )
    end

    it 'includes different fields types', :show_in_doc do
      create(:form_field_attachment, fieldable: campaign)
      create(:form_field_brand, fieldable: campaign)
      create(:form_field_checkbox, fieldable: campaign, options: [
        create(:form_field_option, name: 'Option 1'),
        create(:form_field_option, name: 'Option 2'),
        create(:form_field_option, name: 'Option 3')
      ])
      f = create(:form_field_number, fieldable: campaign, required: true, settings: {
                   'range_format' => 'value',
                   'range_min' => '1',
                   'range_max' => '100'
                 })
      event.results_for([f]).first.value = 10
      create(:form_field_section, fieldable: campaign, settings: {
               'description' => 'This is a section description'
             })
      create(:form_field_text, fieldable: campaign, settings: {
               'range_format' => 'words',
               'range_min' => '20',
               'range_max' => ''
             })
      create(:form_field_likert_scale,
             fieldable: campaign,
             options: [
               create(:form_field_option, name: 'Option 1'),
               create(:form_field_option, name: 'Option 2'),
               create(:form_field_option, name: 'Option 3')],
             statements: [
               create(:form_field_statement, name: 'Statement 1'),
               create(:form_field_statement, name: 'Statement 2'),
               create(:form_field_statement, name: 'Statement 3')])
      create(:form_field_percentage, fieldable: campaign, required: true, options: [
        create(:form_field_option, name: 'Option 1'),
        create(:form_field_option, name: 'Option 2'),
        create(:form_field_option, name: 'Option 3')
      ])
      create(:form_field_photo, fieldable: campaign)
      create(:form_field_radio, fieldable: campaign)
      create(:form_field_section, fieldable: campaign)
      f = create(:form_field_calculation, name: 'Fruits', fieldable: campaign, options: [
        o1 = create(:form_field_option, name: 'Apples'),
        o2 = create(:form_field_option, name: 'Oranges'),
        o3 = create(:form_field_option, name: 'Bananas')
      ])
      event.results_for([f]).first.value = { o1.id.to_s => 2, o2.id.to_s => 3, o3.id.to_s => 5 }
      create(:form_field_text, fieldable: campaign)
      create(:form_field_text_area, fieldable: campaign)
      create(:form_field_time, fieldable: campaign)
      expect(event.save).to be_truthy
      get 'results', id: event.to_param, format: :json
      expect(json.first['fields'].count).to eql 15
    end
  end

  describe "GET 'members'" do
    let(:event) { create(:event, company: company, campaign: create(:campaign, company: company)) }
    it 'return a list of users' do
      users = [
        create(:company_user, user: create(:user, first_name: 'Luis', last_name: 'Perez', email: 'luis@gmail.com', street_address: 'ABC 1', unit_number: '#123 2nd floor', zip_code: 12_345), role: create(:role, name: 'Field Ambassador', company: event.company), company: event.company),
        create(:company_user, user: create(:user, first_name: 'Pedro', last_name: 'Guerra', email: 'pedro@gmail.com', street_address: 'ABC 1', unit_number: '#123 2nd floor', zip_code: 12_345), role: create(:role, name: 'Coach', company: event.company), company: event.company)
      ]
      event.users << users

      get :members, id: event.to_param, format: :json
      expect(response).to be_success
      result = JSON.parse(response.body)
      expect(result).to match_array([
        { 'id' => users.last.id, 'first_name' => 'Pedro', 'last_name' => 'Guerra',
          'full_name' => 'Pedro Guerra', 'role_name' => 'Coach', 'email' => 'pedro@gmail.com',
          'phone_number' => '+1000000000', 'street_address' => 'ABC 1',
          'unit_number' => '#123 2nd floor', 'city' => 'Curridabat', 'state' => 'SJ',
          'zip_code' => '12345', 'time_zone' => 'Pacific Time (US & Canada)',
          'country' => 'Costa Rica', 'type' => 'user' },
        { 'id' => users.first.id, 'first_name' => 'Luis', 'last_name' => 'Perez',
          'full_name' => 'Luis Perez', 'role_name' => 'Field Ambassador',
          'email' => 'luis@gmail.com', 'phone_number' => '+1000000000', 'street_address' => 'ABC 1',
          'unit_number' => '#123 2nd floor', 'city' => 'Curridabat', 'state' => 'SJ',
          'zip_code' => '12345', 'time_zone' => 'Pacific Time (US & Canada)', 'country' => 'Costa Rica',
          'type' => 'user' }
      ])
    end

    it 'return a list of teams' do
      teams = [
        create(:team, name: 'Team C', description: 'team 3 description'),
        create(:team, name: 'Team A', description: 'team 1 description'),
        create(:team, name: 'Team B', description: 'team 2 description')
      ]
      company_user = user.company_users.first
      event.teams << teams
      event.users << company_user
      get :members, id: event.to_param, format: :json
      expect(response).to be_success
      result = JSON.parse(response.body)
      company_user = user.company_users.first
      expect(result).to match_array([
        { 'id' => teams.second.id, 'name' => 'Team A', 'description' => 'team 1 description', 'type' => 'team' },
        { 'id' => teams.last.id, 'name' => 'Team B', 'description' => 'team 2 description', 'type' => 'team' },
        { 'id' => teams.first.id, 'name' => 'Team C', 'description' => 'team 3 description', 'type' => 'team' },
        { 'id' => company_user.id, 'first_name' => 'Test', 'last_name' => 'User', 'full_name' => 'Test User', 'role_name' => 'Super Admin', 'email' => user.email, 'phone_number' => '+1000000000', 'street_address' => 'Street Address 123', 'unit_number' => 'Unit Number 456', 'city' => 'Curridabat', 'state' => 'SJ', 'zip_code' => '90210', 'time_zone' => 'Pacific Time (US & Canada)', 'country' => 'Costa Rica', 'type' => 'user' }
      ])
    end

    describe 'event with users and teams', :show_in_doc do
      before do
        @users = [
          create(:company_user, user: create(:user, first_name: 'A', last_name: 'User', email: 'luis@gmail.com', street_address: 'ABC 1', unit_number: '#123 2nd floor', zip_code: 12_345), role: create(:role, name: 'Field Ambassador', company: company), company: company),
          create(:company_user, user: create(:user, first_name: 'User', last_name: '2', email: 'pedro@gmail.com', street_address: 'ABC 1', unit_number: '#123 2nd floor', zip_code: 12_345), role: create(:role, name: 'Coach', company: company), company: company)
        ]
        @teams = [
          create(:team, name: 'A team', description: 'team 1 description'),
          create(:team, name: 'Team 2', description: 'team 2 description')
        ]
        event.users << @users
        event.teams << @teams
      end

      it 'return a mixed list of users and teams' do
        company_user = user.company_users.first
        event.users << company_user
        get :members, id: event.to_param, format: :json
        expect(response).to be_success
        result = JSON.parse(response.body)
        expect(result).to match_array([
          { 'id' => @teams.first.id, 'name' => 'A team', 'description' => 'team 1 description', 'type' => 'team' },
          { 'id' => @users.first.id, 'first_name' => 'A', 'last_name' => 'User', 'full_name' => 'A User', 'role_name' => 'Field Ambassador', 'email' => 'luis@gmail.com', 'phone_number' => '+1000000000', 'street_address' => 'ABC 1', 'unit_number' => '#123 2nd floor', 'city' => 'Curridabat', 'state' => 'SJ', 'zip_code' => '12345', 'time_zone' => 'Pacific Time (US & Canada)', 'country' => 'Costa Rica', 'type' => 'user' },
          { 'id' => @teams.last.id, 'name' => 'Team 2', 'description' => 'team 2 description', 'type' => 'team' },
          { 'id' => @users.last.id, 'first_name' => 'User', 'last_name' => '2', 'full_name' => 'User 2', 'role_name' => 'Coach', 'email' => 'pedro@gmail.com', 'phone_number' => '+1000000000', 'street_address' => 'ABC 1', 'unit_number' => '#123 2nd floor', 'city' => 'Curridabat', 'state' => 'SJ', 'zip_code' => '12345', 'time_zone' => 'Pacific Time (US & Canada)', 'country' => 'Costa Rica', 'type' => 'user' },
          { 'id' => company_user.id, 'first_name' => 'Test', 'last_name' => 'User', 'full_name' => 'Test User', 'role_name' => 'Super Admin', 'email' => user.email, 'phone_number' => '+1000000000', 'street_address' => 'Street Address 123', 'unit_number' => 'Unit Number 456', 'city' => 'Curridabat', 'state' => 'SJ', 'zip_code' => '90210', 'time_zone' => 'Pacific Time (US & Canada)', 'country' => 'Costa Rica', 'type' => 'user' }
        ])
      end

      it 'returns only the users' do
        company_user = user.company_users.first
        event.users << company_user
        get :members, id: event.to_param, type: 'user', format: :json
        expect(response).to be_success
        result = JSON.parse(response.body)
        expect(result).to match_array([
          { 'id' => @users.first.id, 'first_name' => 'A', 'last_name' => 'User', 'full_name' => 'A User', 'role_name' => 'Field Ambassador', 'email' => 'luis@gmail.com', 'phone_number' => '+1000000000', 'street_address' => 'ABC 1', 'unit_number' => '#123 2nd floor', 'city' => 'Curridabat', 'state' => 'SJ', 'zip_code' => '12345', 'time_zone' => 'Pacific Time (US & Canada)', 'country' => 'Costa Rica', 'type' => 'user' },
          { 'id' => @users.last.id, 'first_name' => 'User', 'last_name' => '2', 'full_name' => 'User 2', 'role_name' => 'Coach', 'email' => 'pedro@gmail.com', 'phone_number' => '+1000000000', 'street_address' => 'ABC 1', 'unit_number' => '#123 2nd floor', 'city' => 'Curridabat', 'state' => 'SJ', 'zip_code' => '12345', 'time_zone' => 'Pacific Time (US & Canada)', 'country' => 'Costa Rica', 'type' => 'user' },
          { 'id' => company_user.id, 'first_name' => 'Test', 'last_name' => 'User', 'full_name' => 'Test User', 'role_name' => 'Super Admin', 'email' => user.email, 'phone_number' => '+1000000000', 'street_address' => 'Street Address 123', 'unit_number' => 'Unit Number 456', 'city' => 'Curridabat', 'state' => 'SJ', 'zip_code' => '90210', 'time_zone' => 'Pacific Time (US & Canada)', 'country' => 'Costa Rica', 'type' => 'user' }
        ])
      end

      it 'returns only the team' do
        get :members, id: event.to_param, type: 'team', format: :json
        expect(response).to be_success
        result = JSON.parse(response.body)

        expect(result).to eq([
          { 'id' => @teams.first.id, 'name' => 'A team', 'description' => 'team 1 description', 'type' => 'team' },
          { 'id' => @teams.last.id, 'name' => 'Team 2', 'description' => 'team 2 description', 'type' => 'team' }
        ])
      end
    end
  end

  describe "GET 'contacts'" do
    let(:event) { create(:event, company: company, campaign: create(:campaign, company: company)) }
    it 'return a list of contacts' do
      contacts = [
        create(:contact, first_name: 'Luis', last_name: 'Perez', email: 'luis@gmail.com',
                         street1: 'ABC', street2: '1', zip_code: 12_345,
                         city: 'Leon', country: 'MX', state: 'GUA',
                         title: 'Field Ambassador', company_name: 'Tres Patitos Inc'),
        create(:contact, first_name: 'Tony', last_name: 'Stark', email: 'tony@starkindustries.com',
                         city: 'Los Angeles', country: 'US', state: 'CA',
                         street1: 'ABC', street2: '1', zip_code: 23_222,
                         title: 'CEO', company_name: 'Stark Industries')
      ]
      create(:contact_event, event: event, contactable: contacts.first)
      create(:contact_event, event: event, contactable: contacts.last)

      get :contacts, id: event.to_param, format: :json
      expect(response).to be_success
      result = JSON.parse(response.body)

      expect(result).to match_array([
        { 'id' => contacts.first.id, 'first_name' => 'Luis', 'last_name' => 'Perez',
          'full_name' => 'Luis Perez', 'title' => 'Field Ambassador',
          'company_name' => 'Tres Patitos Inc', 'email' => 'luis@gmail.com',
          'phone_number' => '344-23333', 'street1' => 'ABC', 'street2' => '1',
          'street_address' => 'ABC, 1', 'city' => 'Leon', 'state' => 'GUA',
          'zip_code' => '12345', 'country' => 'MX', 'country_name' => 'Mexico',
          'type' => 'contact' },
        { 'id' => contacts.last.id, 'first_name' => 'Tony', 'last_name' => 'Stark',
          'full_name' => 'Tony Stark', 'title' => 'CEO', 'company_name' => 'Stark Industries',
          'email' => 'tony@starkindustries.com', 'phone_number' => '344-23333', 'street1' => 'ABC',
          'street2' => '1', 'street_address' => 'ABC, 1', 'city' => 'Los Angeles', 'state' => 'CA',
          'zip_code' => '23222', 'country' => 'US', 'country_name' => 'United States',
          'type' => 'contact' }
      ])
    end

    it 'users can also be added as contacts' do
      company_user = user.company_users.first
      create(:contact_event, event: event, contactable: company_user)

      get :contacts, id: event.to_param, format: :json
      expect(response).to be_success
      result = JSON.parse(response.body)

      expect(result).to match_array([
        { 'id' => company_user.id, 'first_name' => 'Test', 'last_name' => 'User',
          'full_name' => 'Test User', 'role_name' => 'Super Admin', 'email' => user.email,
          'phone_number' => '+1000000000', 'street_address' => 'Street Address 123',
          'unit_number' => 'Unit Number 456', 'city' => 'Curridabat', 'state' => 'SJ',
          'zip_code' => '90210', 'time_zone' => 'Pacific Time (US & Canada)',
          'country' => 'Costa Rica', 'type' => 'user' }
      ])
    end

    it 'return a mixed list of contacts and users', :show_in_doc do
      contacts = [
        create(:contact, first_name: 'Luis', last_name: 'Perez',
                         email: 'luis@gmail.com', street1: 'ABC', street2: '1',
                         company_name: 'Internet Inc', city: 'Hollywood', state: 'CA',
                         zip_code: 12_345, title: 'Field Ambassador'),
        create(:contact, first_name: 'Pedro', last_name: 'Guerra',
                         email: 'pedro@gmail.com', street1: 'ABC', street2: '1',
                         company_name: 'Cable Inc', city: 'Hollywood', state: 'CA',
                         zip_code: 12_345, title: 'Coach')
      ]
      create(:contact_event, event: event, contactable: contacts.first)
      create(:contact_event, event: event, contactable: contacts.last)

      company_user = create(:company_user,
                            company: company,
                            role: create(:role, company: company, name: 'Physicist'),
                            user: create(:user, first_name: 'Albert', last_name: 'Einstain',
                                                email: 'albert@einstain.com', country: 'DE',
                                                city: 'Ulm', state: 'BW'))
      create(:contact_event, event: event, contactable: company_user)

      get :contacts, id: event.to_param, format: :json
      expect(response).to be_success
      result = JSON.parse(response.body)

      expect(result).to match_array([
        { 'id' => company_user.id, 'first_name' => 'Albert', 'last_name' => 'Einstain',
          'full_name' => 'Albert Einstain', 'role_name' => 'Physicist',
          'email' => 'albert@einstain.com', 'phone_number' => '+1000000000',
          'street_address' => 'Street Address 123', 'unit_number' => 'Unit Number 456',
          'city' => 'Ulm', 'state' => 'BW', 'zip_code' => '90210',
          'time_zone' => 'Pacific Time (US & Canada)', 'country' => 'Germany',
          'type' => 'user'  },
        { 'id' => contacts.first.id, 'first_name' => 'Luis', 'last_name' => 'Perez',
          'full_name' => 'Luis Perez', 'company_name' => 'Internet Inc',
          'title' => 'Field Ambassador', 'email' => 'luis@gmail.com',
          'phone_number' => '344-23333', 'street1' => 'ABC', 'street2' => '1',
          'street_address' => 'ABC, 1', 'city' => 'Hollywood', 'state' => 'CA',
          'zip_code' => '12345', 'country' => 'US', 'country_name' => 'United States',
          'type' => 'contact' },
        { 'id' => contacts.last.id, 'first_name' => 'Pedro', 'last_name' => 'Guerra',
          'full_name' => 'Pedro Guerra', 'company_name' => 'Cable Inc', 'title' => 'Coach',
          'email' => 'pedro@gmail.com', 'phone_number' => '344-23333', 'street1' => 'ABC',
          'street2' => '1', 'street_address' => 'ABC, 1', 'city' => 'Hollywood',
          'state' => 'CA', 'zip_code' => '12345', 'country' => 'US',
          'country_name' => 'United States', 'type' => 'contact' }
      ])
    end
  end

  describe "GET 'assignable_members'" do
    let(:event) { create(:event, company: company, campaign: create(:campaign, company: company)) }
    it 'return a list of users that are not assined to the event' do
      users = [
        create(:company_user, user: create(:user, first_name: 'Luis', last_name: 'Perez',
                                                  email: 'luis@gmail.com', street_address: 'ABC 1',
                                                  unit_number: '#123 2nd floor', zip_code: 12_345),
                              role: create(:role, name: 'Field Ambassador', company: company),
                              company: company),
        create(:company_user, user: create(:user, first_name: 'Pedro', last_name: 'Guerra',
                                                  email: 'pedro@gmail.com', street_address: 'ABC 1',
                                                  unit_number: '#123 2nd floor', zip_code: 12_345),
                              role: create(:role, name: 'Coach', company: company),
                              company: company)
      ]

      event.users << user.company_users.first

      get :assignable_members, id: event.to_param, format: :json
      expect(response).to be_success
      result = JSON.parse(response.body)

      expect(result).to match_array([
        { 'id' => users.first.id.to_s, 'name' => 'Luis Perez',   'description' => 'Field Ambassador', 'type' => 'user' },
        { 'id' => users.last.id.to_s,  'name' => 'Pedro Guerra', 'description' => 'Coach', 'type' => 'user' }
      ])
    end

    it 'returns users and teams mixed on the list', :show_in_doc do
      teams = [
        create(:team, name: 'Z Team', description: 'team 3 description', company: company),
        create(:team, name: 'Team A', description: 'team 1 description', company: company),
        create(:team, name: 'Team B', description: 'team 2 description', company: company)
      ]
      company_user = user.company_users.first
      teams.each { |t| t.users << company_user }

      get :assignable_members, id: event.to_param, format: :json
      expect(response).to be_success
      result = JSON.parse(response.body)

      expect(result).to match_array([
        { 'id' => teams.second.id.to_s, 'name' => 'Team A', 'description' => 'team 1 description', 'type' => 'team' },
        { 'id' => teams.last.id.to_s, 'name' => 'Team B', 'description' => 'team 2 description', 'type' => 'team' },
        { 'id' => teams.first.id.to_s, 'name' => 'Z Team', 'description' => 'team 3 description', 'type' => 'team' },
        { 'id' => company_user.id.to_s, 'name' => company_user.full_name, 'description' => company_user.role_name, 'type' => 'user' }
      ])
    end
  end

  describe "POST 'add_member'" do
    let(:event) { create(:event, company: company, campaign: create(:campaign, company: company)) }

    it "should add a team to the event's team", :show_in_doc do
      team = create(:team, company: company)
      expect do
        post :add_member, id: event.to_param, memberable_id: team.id, memberable_type: 'team', format: :json
      end.to change(Teaming, :count).by(1)
      expect(event.teams).to eq([team])

      expect(response).to be_success
      result = JSON.parse(response.body)
      expect(result).to eq('success' => true, 'info' => 'Member successfully added to event', 'data' => {})
    end

    it "should add a user to the event's team", :show_in_doc do
      company_user = create(:company_user, company_id: company.to_param)
      expect do
        post :add_member, id: event.to_param, memberable_id: company_user.id, memberable_type: 'user', format: :json
      end.to change(Membership, :count).by(1)
      expect(event.users).to match_array([company_user])

      expect(response).to be_success
      result = JSON.parse(response.body)
      expect(result).to eq('success' => true, 'info' => 'Member successfully added to event', 'data' => {})
    end
  end

  describe "DELETE 'delete_member'" do
    let(:event) { create(:event, company: company, campaign: create(:campaign, company: company)) }

    it 'should remove a member (type = user) from the event', :show_in_doc do
      member_to_delete = create(:company_user, company: company)
      another_member = create(:team, name: 'A team', description: 'team 1 description')
      event.users << member_to_delete
      event.teams << another_member

      expect do
        delete :delete_member, id: event.to_param,
                               memberable_id: member_to_delete.id, memberable_type: 'user',
                               format: :json
      end.to change(Membership, :count).by(-1)
      event.reload
      expect(event.users).to be_empty
      expect(event.teams).to eq([another_member])

      expect(response).to be_success
      expect(response.response_code).to eq(200)
      result = JSON.parse(response.body)
      expect(result).to eq('success' => true,
                           'info' => 'Member successfully deleted from event',
                           'data' => {})
    end

    it 'should remove a member (type = team) from the event', :show_in_doc do
      member_to_delete = create(:team, company: company)
      another_member = create(:company_user, company: company)
      event.users << another_member
      event.teams << member_to_delete

      expect do
        delete :delete_member, id: event.to_param,
                               memberable_id: member_to_delete.id,
                               memberable_type: 'team', format: :json
      end.to change(Teaming, :count).by(-1)
      event.reload
      expect(event.users).to match_array([another_member])
      expect(event.teams).to eq([])

      expect(response).to be_success
      expect(response.response_code).to eq(200)
      result = JSON.parse(response.body)
      expect(result).to eq('success' => true,
                           'info' => 'Member successfully deleted from event',
                           'data' => {})
    end

    it 'return 404 if the member is not found' do
      member = create(:company_user, company: company)

      expect do
        delete :delete_member, id: event.to_param, memberable_id: member.id,
                               memberable_type: 'user', format: :json
      end.to_not change(Membership, :count)
      event.reload
      expect(event.users).to eq([])
      expect(event.teams).to eq([])

      expect(response).not_to be_success
      expect(response.response_code).to eq(404)
      result = JSON.parse(response.body)
      expect(result).to eq('success' => false,
                           'info' => 'Record not found', 'data' => {})
    end
  end

  describe "GET 'assignable_contacts'", search: true do
    let(:event) { create(:event, company: company, campaign: create(:campaign, company: company)) }
    it 'return a list of contacts that are not assined to the event' do
      contacts = [
        create(:contact, first_name: 'Luis', last_name: 'Perez', email: 'luis@gmail.com', street1: 'ABC', street2: '1', zip_code: 12_345, title: 'Field Ambassador', company: company),
        create(:contact, first_name: 'Pedro', last_name: 'Guerra', email: 'pedro@gmail.com', street1: 'ABC', street2: '1', zip_code: 12_345, title: 'Coach', company: company)
      ]

      associated_contact = create(:contact, first_name: 'Juan', last_name: 'Rodriguez', email: 'juan@gmail.com', street1: 'ABC', street2: '1', zip_code: 12_345, title: 'Field Ambassador')
      create(:contact_event, event: event, contactable: associated_contact)   # this contact should not be returned on the list
      create(:contact_event, event: event, contactable: user.company_users.first) # Also associate the current user so it's not returned in the results

      Sunspot.commit

      get :assignable_contacts, id: event.to_param, format: :json
      expect(response).to be_success
      result = JSON.parse(response.body)

      expect(result).to match_array([
        { 'id' => contacts.first.id, 'full_name' => 'Luis Perez', 'title' => 'Field Ambassador', 'type' => 'contact' },
        { 'id' => contacts.last.id, 'full_name' => 'Pedro Guerra', 'title' => 'Coach', 'type' => 'contact' }
      ])
    end

    it 'returns users and contacts mixed on the list', :show_in_doc do
      contacts = [
        create(:contact, first_name: 'Luis', last_name: 'Perez', email: 'luis@gmail.com', street1: 'ABC', street2: '1', zip_code: 12_345, title: 'Field Ambassador', company: company),
        create(:contact, first_name: 'Pedro', last_name: 'Guerra', email: 'pedro@gmail.com', street1: 'ABC', street2: '1', zip_code: 12_345, title: 'Coach', company: company)
      ]
      company_user = user.company_users.first
      Sunspot.commit

      get :assignable_contacts, id: event.to_param, format: :json
      expect(response).to be_success
      result = JSON.parse(response.body)

      expect(result).to match_array([
        { 'id' => contacts.first.id, 'full_name' => 'Luis Perez', 'title' => 'Field Ambassador', 'type' => 'contact' },
        { 'id' => contacts.last.id, 'full_name' => 'Pedro Guerra', 'title' => 'Coach', 'type' => 'contact' },
        { 'id' => company_user.id, 'full_name' => company_user.full_name, 'title' => company_user.role_name, 'type' => 'user' }
      ])
    end

    it 'returns results match a search term' do
      contacts = [
        create(:contact, first_name: 'Luis', last_name: 'Perez', email: 'luis@gmail.com', street1: 'ABC', street2: '1', zip_code: 12_345, title: 'Field Ambassador', company: company),
        create(:contact, first_name: 'Pedro', last_name: 'Guerra', email: 'pedro@gmail.com', street1: 'ABC', street2: '1', zip_code: 12_345, title: 'Coach', company: company)
      ]
      Sunspot.commit

      get :assignable_contacts, id: event.to_param, term: 'luis', format: :json
      expect(response).to be_success
      result = JSON.parse(response.body)

      expect(result).to match_array([
        { 'id' => contacts.first.id, 'full_name' => 'Luis Perez', 'title' => 'Field Ambassador', 'type' => 'contact' }
      ])
    end
  end

  describe "POST 'add_contact'" do
    let(:event) { create(:event, company: company, campaign: create(:campaign, company: company)) }

    it 'should add a contact to the event as a contact', :show_in_doc do
      contact = create(:contact, first_name: 'Luis', last_name: 'Perez', email: 'luis@gmail.com', street1: 'ABC', street2: '1', zip_code: 12_345, title: 'Field Ambassador', company: company)
      expect do
        post :add_contact, id: event.to_param, contactable_id: contact.id, contactable_type: 'contact', format: :json
      end.to change(ContactEvent, :count).by(1)
      expect(event.contacts).to eq([contact])

      expect(response).to be_success
      result = JSON.parse(response.body)
      expect(result).to eq('success' => true, 'info' => 'Contact successfully added to event', 'data' => {})
    end

    it 'should add a user to the event as a contact' do
      company_user = user.company_users.first
      expect do
        post :add_contact, id: event.to_param, contactable_id: company_user.id, contactable_type: 'user', format: :json
      end.to change(ContactEvent, :count).by(1)
      expect(event.contacts).to eq([company_user])

      expect(response).to be_success
      result = JSON.parse(response.body)
      expect(result).to eq('success' => true, 'info' => 'Contact successfully added to event', 'data' => {})
    end
  end

  describe "DELETE 'delete_contact'" do
    let(:event) { create(:event, company: company, campaign: create(:campaign, company: company)) }

    it 'should remove a contact (type = user) from the event', :show_in_doc do
      contact_to_delete = create(:company_user, user: create(:user, first_name: 'Pedro', last_name: 'Guerra', email: 'pedro@gmail.com', street_address: 'ABC 1', unit_number: '#123 2nd floor', zip_code: 12_345), role: create(:role, name: 'Coach', company: event.company))
      another_contact = create(:contact, first_name: 'Juan', last_name: 'Rodriguez', email: 'juan@gmail.com', street1: 'ABC', street2: '1', zip_code: 12_345, title: 'Field Ambassador')
      create(:contact_event, event: event, contactable: contact_to_delete)
      create(:contact_event, event: event, contactable: another_contact)

      expect do
        delete :delete_contact, id: event.to_param, contactable_id: contact_to_delete.id, contactable_type: 'user', format: :json
      end.to change(ContactEvent, :count).by(-1)
      expect(event.contacts).to eq([another_contact])

      expect(response).to be_success
      expect(response.response_code).to eq(200)
      result = JSON.parse(response.body)
      expect(result).to eq('success' => true, 'info' => 'Contact successfully deleted from event', 'data' => {})
    end

    it 'should remove a contact (type = contact) from the event' do
      contact_to_delete = create(:contact, first_name: 'Juan', last_name: 'Rodriguez', email: 'juan@gmail.com', street1: 'ABC', street2: '1', zip_code: 12_345, title: 'Field Ambassador')
      another_contact = user.company_users.first
      create(:contact_event, event: event, contactable: contact_to_delete)
      create(:contact_event, event: event, contactable: another_contact)

      expect do
        delete :delete_contact, id: event.to_param, contactable_id: contact_to_delete.id, contactable_type: 'contact', format: :json
      end.to change(ContactEvent, :count).by(-1)
      expect(event.contacts).to eq([another_contact])

      expect(response).to be_success
      expect(response.response_code).to eq(200)
      result = JSON.parse(response.body)
      expect(result).to eq('success' => true, 'info' => 'Contact successfully deleted from event', 'data' => {})
    end

    it 'return 404 if the contact is not found' do
      contact = create(:contact, first_name: 'Luis', last_name: 'Perez', email: 'luis@gmail.com', street1: 'ABC', street2: '1', zip_code: 12_345, title: 'Field Ambassador', company: company)

      expect do
        delete :delete_contact, id: event.to_param, contactable_id: contact.id, contactable_type: 'contact', format: :json
      end.to change(ContactEvent, :count).by(0)

      expect(event.contacts).to eq([])

      expect(response).not_to be_success
      expect(response.response_code).to eq(404)
      result = JSON.parse(response.body)
      expect(result).to eq('success' => false, 'info' => 'Record not found', 'data' => {})
    end
  end

  describe "GET 'autocomplete'", :search do
    it 'should return the correct buckets in the right order', :show_in_doc do
      get 'autocomplete', q: '', format: :json
      expect(response).to be_success

      expect(json.map { |b| b['label'] }).to eq([
        'Campaigns', 'Brands', 'Places', 'People', 'Active State', 'Event Status'])
    end

    it 'should return the users in the People Bucket' do
      user = create(:user, first_name: 'Guillermo', last_name: 'Vargas', company_id: company.id)
      company_user = user.company_users.first
      Sunspot.commit

      get 'autocomplete', q: 'gu', format: :json
      expect(response).to be_success

      people_bucket = json.select { |b| b['label'] == 'People' }.first
      expect(people_bucket['value']).to eq([{ 'label' => '<i>Gu</i>illermo Vargas', 'value' => company_user.id.to_s, 'type' => 'user' }])
    end

    it 'should return the teams in the People Bucket' do
      team = create(:team, name: 'Spurs', company_id: company.id)
      Sunspot.commit

      get 'autocomplete', q: 'sp', format: :json
      expect(response).to be_success

      people_bucket = json.select { |b| b['label'] == 'People' }.first
      expect(people_bucket['value']).to eq([{ 'label' => '<i>Sp</i>urs', 'value' => team.id.to_s, 'type' => 'team' }])
    end

    it 'should return the teams and users in the People Bucket' do
      team = create(:team, name: 'Valladolid', company_id: company.id)
      user = create(:user, first_name: 'Guillermo', last_name: 'Vargas', company_id: company.id)
      company_user = user.company_users.first
      Sunspot.commit

      get 'autocomplete', q: 'va', format: :json
      expect(response).to be_success

      people_bucket = json.select { |b| b['label'] == 'People' }.first
      expect(people_bucket['value']).to eq([{ 'label' => '<i>Va</i>lladolid', 'value' => team.id.to_s, 'type' => 'team' }, { 'label' => 'Guillermo <i>Va</i>rgas', 'value' => company_user.id.to_s, 'type' => 'user' }])
    end

    it 'should return the campaigns in the Campaigns Bucket' do
      campaign = create(:campaign, name: 'Cacique para todos', company_id: company.id)
      Sunspot.commit

      get 'autocomplete', q: 'cac', format: :json
      expect(response).to be_success

      campaigns_bucket = json.select { |b| b['label'] == 'Campaigns' }.first
      expect(campaigns_bucket['value']).to eq([{ 'label' => '<i>Cac</i>ique para todos', 'value' => campaign.id.to_s, 'type' => 'campaign' }])
    end

    it 'should return the brands in the Brands Bucket' do
      brand = create(:brand, name: 'Cacique', company_id: company.to_param)
      Sunspot.commit

      get 'autocomplete', q: 'cac', format: :json
      expect(response).to be_success

      brands_bucket = json.select { |b| b['label'] == 'Brands' }.first
      expect(brands_bucket['value']).to eq([{ 'label' => '<i>Cac</i>ique', 'value' => brand.id.to_s, 'type' => 'brand' }])
    end

    it 'should return the venues in the Places Bucket' do
      expect_any_instance_of(Place).to receive(:fetch_place_data).and_return(true)
      venue = create(:venue, company_id: company.id, place: create(:place, name: 'Motel Paraiso'))
      Sunspot.commit

      get 'autocomplete', q: 'mot', format: :json
      expect(response).to be_success

      places_bucket = json.select { |b| b['label'] == 'Places' }.first
      expect(places_bucket['value']).to eq([{ 'label' => '<i>Mot</i>el Paraiso', 'value' => venue.id.to_s, 'type' => 'venue' }])
    end
  end
end
