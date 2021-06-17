require 'rails_helper'

describe EventsController, type: :controller do
  describe 'as registered user' do
    let(:user) { sign_in_as_user }
    let(:company) { user.companies.first }
    let(:company_user) { user.current_company_user }

    before { user }
    after { Timecop.return }

    describe "GET 'new'" do
      it 'returns http success' do
        xhr :get, 'new', format: :js
        expect(response).to be_success
        expect(response).to render_template('new')
        expect(response).to render_template('_form')
      end
    end

    describe "GET 'edit'" do
      let(:event) { create(:event, company: company, campaign: create(:campaign, company: company)) }
      it 'returns http success' do
        xhr :get, 'edit', id: event.to_param, format: :js
        expect(response).to be_success
      end
    end

    describe "GET 'edit_data'" do
      let(:event) { create(:event, company: company, campaign: create(:campaign, company: company)) }
      it 'returns http success' do
        event.build_event_data.save
        xhr :get, 'edit_data', id: event.to_param, format: :js
        expect(response).to be_success
        expect(response).to render_template('edit_data')
      end
    end

    describe "GET 'edit_surveys'" do
      let(:event) { create(:event, company: company) }
      it 'returns http success' do
        xhr :get, 'edit_surveys', id: event.to_param, format: :js
        expect(response).to be_success
        expect(response).to render_template('edit_surveys')
        expect(response).to render_template('_surveys')
      end
    end

    describe "GET 'show'" do
      describe 'for an event in the future' do
        let(:event) do
          create(:event, company: company, campaign: create(:campaign, company: company),
                         start_date: 1.week.from_now.to_s(:slashes),
                         end_date: 1.week.from_now.to_s(:slashes))
        end

        it 'renders the correct templates' do
          event.users << company_user
          expect do
            get 'show', id: event.to_param
          end.to change(Notification, :count).by(-1)
          expect(response).to be_success
          expect(response).to render_template('show')
          expect(response).not_to render_template('show_results')
          expect(response).not_to render_template('edit_results')
        end

        it 'sets the flash message after activities have been created' do
          activity_type = create(:activity_type, name: 'POS Drop', company: company, campaigns: [event.campaign])
          session['activity_create_123'] = 3
          get 'show', id: event.id, activity_form: 123, activity_type_id: activity_type.id
          expect(flash[:event_message_success]).to eql 'Nice work. 3 POS Drop activities have been added.'
        end
      end

      describe 'for an event in the past' do
        let(:event) do
          create(:event, company: company, campaign: create(:campaign, company: company),
                         start_date: 1.day.ago.to_s(:slashes), end_date: 1.day.ago.to_s(:slashes))
        end

        describe 'when no data have been entered' do
          it 'renders the correct templates' do
            Kpi.create_global_kpis
            event.campaign.assign_all_global_kpis
            get 'show', id: event.to_param
            expect(response).to be_success
            expect(response).to render_template('show')
            expect(response).to render_template('_basic_info')
            expect(response).to render_template('_edit_event_data')
            expect(response).to render_template('_comments')
            expect(response).to render_template('_photos')
            expect(response).to render_template('_expenses')
          end
        end
      end
    end

    describe "GET 'index'" do
      it 'returns http success' do
        get 'index'
        expect(response).to be_success
      end

      describe 'calendar_highlights' do
        it 'loads the highligths for the calendar' do
          create(:event, company: company, start_date: '01/23/2013', end_date: '01/24/2013')
          create(:event, company: company, start_date: '02/15/2013', end_date: '02/15/2013')
          get 'index'
          expect(response).to be_success
          expect(assigns(:calendar_highlights)).to eq(2013 => { 1 => { 23 => 1, 24 => 1 }, 2 => { 15 => 1 } })
        end

        ActiveSupport::TimeZone.all.each do |zone|
          it "works when time zone is set to '#{zone.name}'" do
            user.update_attribute :time_zone, zone.name
            get 'index'
            expect(response).to be_success
            expect(assigns(:calendar_highlights)).to eq({})
          end
        end
      end

      it 'queue the job for export the list' do
        expect(ListExportWorker).to receive(:perform_async).with(kind_of(Numeric))
        expect do
          xhr :get, :index, format: :csv
        end.to change(ListExport, :count).by(1)
        export = ListExport.last
      end
    end

    describe "GET 'list_export'", :search, :inline_jobs do
      let(:campaign) { create(:campaign, company: company, name: 'Test Campaign FY01') }
      it 'should return an empty book with the correct headers' do
        expect { xhr :get, 'index', format: :csv }.to change(ListExport, :count).by(1)
        expect(ListExport.last).to have_rows([
          ['CAMPAIGN NAME', 'AREA', 'START', 'END', 'DURATION', 'VENUE NAME', 'ADDRESS', 'CITY',
           'STATE', 'ZIP', 'EVENT DESCRIPTION', 'ACTIVE STATE', 'EVENT STATUS', 'TEAM MEMBERS', 'CONTACTS', 'URL']
        ])
      end

      it 'should include the event results' do
        place = create(:place, name: 'Bar Prueba', city: 'Los Angeles', state: 'California', country: 'US')
        event = create(:approved_event, company: company, campaign: campaign, description: 'Approved Event',
                                        start_date: '01/23/2019', end_date: '01/23/2019',
                                        start_time: '10:00 am', end_time: '12:00 pm',
                                        place: place)
        team = create(:team, company: company, name: 'zteam')
        event.teams << team
        event.users << company_user
        contact1 = create(:contact, first_name: 'Guillermo', last_name: 'Vargas',
                                    email: 'guilleva@gmail.com', company: company)
        contact2 = create(:contact, first_name: 'Chris', last_name: 'Jaskot',
                                    email: 'cjaskot@gmail.com', company: company)
        create(:contact_event, event: event, contactable: contact1)
        create(:contact_event, event: event, contactable: contact2)
        Sunspot.commit

        expect { xhr :get, 'index', format: :csv }.to change(ListExport, :count).by(1)
        expect(ListExport.last).to have_rows([
          ['CAMPAIGN NAME', 'AREA', 'START', 'END', 'DURATION', 'VENUE NAME', 'ADDRESS', 'CITY',
           'STATE', 'ZIP', 'EVENT DESCRIPTION', 'ACTIVE STATE', 'EVENT STATUS', 'TEAM MEMBERS', 'CONTACTS', 'URL'],
          ['Test Campaign FY01', '', '2019-01-23 10:00', '2019-01-23 12:00', '2.00',
           'Bar Prueba', 'Bar Prueba, 11 Main St., Los Angeles, California, 12345', 'Los Angeles', 'California',
           '12345', 'Approved Event', 'Active', 'Approved', 'Test User, zteam', 'Chris Jaskot, Guillermo Vargas',
           "http://test.host/events/#{event.id}"]
        ])
      end

      it 'should include the event results with the merged place info' do
        place = create(:place, name: 'Bar Prueba', city: 'Los Angeles', state: 'California', country: 'US')
        merged_place = create(:place, name: 'Bar Otra Prueba', city: 'San Francisco', state: 'California',
                                      country: 'US', merged_with_place_id: place.id)

        other_event = create(:approved_event, company: company, campaign: campaign, description: 'Merged Approved Event',
                                              start_date: '02/03/2019', end_date: '02/04/2019',
                                              start_time: '09:00 am', end_time: '10:00 pm',
                                              place: merged_place)
        Sunspot.commit

        expect { xhr :get, 'index', format: :csv }.to change(ListExport, :count).by(1)
        expect(ListExport.last).to have_rows([
          ['CAMPAIGN NAME', 'AREA', 'START', 'END', 'DURATION', 'VENUE NAME', 'ADDRESS', 'CITY',
           'STATE', 'ZIP', 'EVENT DESCRIPTION', 'ACTIVE STATE', 'EVENT STATUS', 'TEAM MEMBERS', 'CONTACTS', 'URL'],
          ['Test Campaign FY01', '', '2019-02-03 09:00', '2019-02-04 22:00', '37.00',
           'Bar Prueba', 'Bar Prueba, 11 Main St., Los Angeles, California, 12345', 'Los Angeles',
           'California', '12345', 'Merged Approved Event', 'Active', 'Approved', '', '',
           "http://test.host/events/#{other_event.id}"]
        ])
      end
    end

    describe "GET 'new'" do
      it 'initializes the event with the correct date' do
        Timecop.freeze(Time.zone.local(2013, 07, 26, 12, 13)) do
          xhr :get, 'new', format: :js
          expect(response).to be_success
          expect(assigns(:event).start_date).to eq(Time.zone.local(2013, 07, 26, 12, 15).to_s(:slashes))
          expect(assigns(:event).start_time).to eq(Time.zone.local(2013, 07, 26, 12, 15).to_s(:time_only))
          expect(assigns(:event).end_date).to eq(Time.zone.local(2013, 07, 26, 13, 15).to_s(:slashes))
          expect(assigns(:event).end_time).to eq(Time.zone.local(2013, 07, 26, 13, 15).to_s(:time_only))
        end
      end

      it 'always choose the hour in the future' do
        Timecop.freeze(Time.zone.local(2013, 07, 26, 12, 01)) do
          xhr :get, 'new', format: :js
          expect(response).to be_success
          expect(assigns(:event).start_date).to eq(Time.zone.local(2013, 07, 26, 12, 15).to_s(:slashes))
          expect(assigns(:event).start_time).to eq(Time.zone.local(2013, 07, 26, 12, 15).to_s(:time_only))
          expect(assigns(:event).end_date).to eq(Time.zone.local(2013, 07, 26, 13, 15).to_s(:slashes))
          expect(assigns(:event).end_time).to eq(Time.zone.local(2013, 07, 26, 13, 15).to_s(:time_only))
        end
      end

      it 'a event that ends on the next day' do
        Timecop.freeze(Time.zone.local(2013, 07, 26, 23, 01)) do
          xhr :get, 'new', format: :js
          expect(response).to be_success
          expect(assigns(:event).start_date).to eq(Time.zone.local(2013, 07, 26, 23, 15).to_s(:slashes))
          expect(assigns(:event).start_time).to eq(Time.zone.local(2013, 07, 26, 23, 15).to_s(:time_only))
          expect(assigns(:event).end_date).to eq(Time.zone.local(2013, 07, 27, 0, 15).to_s(:slashes))
          expect(assigns(:event).end_time).to eq(Time.zone.local(2013, 07, 27, 0, 15).to_s(:time_only))
        end
      end
    end

    describe "GET 'items'" do
      it 'returns http success' do
        get 'items'
        expect(response).to be_success
      end
    end

    describe "POST 'create'" do
      let(:campaign) { create(:campaign, company: company) }
      it 'should not render form_dialog if no errors' do
        expect do
          xhr :post, 'create', event: {
            campaign_id: campaign.id, start_date: '05/23/2020', start_time: '12:00pm',
            end_date: '05/22/2021', end_time: '01:00pm' }, format: :js
        end.to change(Event, :count).by(1)
        expect(response).to be_success
        expect(response).to render_template(:create)
        expect(response).not_to render_template('_form_dialog')
      end

      it 'should render the form_dialog template if errors' do
        expect do
          xhr :post, 'create', event: { campaign_id: 'XX' }, format: :js
        end.not_to change(Event, :count)
        expect(response).to render_template(:create)
        expect(response).to render_template('_form_dialog')
        assigns(:event).errors.count > 0
      end

      it "should assign current_user's company_id to the new event" do
        expect do
          xhr :post, 'create', event: {
            campaign_id: campaign.id, start_date: '05/21/2020', start_time: '12:00pm',
            end_date: '05/22/2020', end_time: '01:00pm' }, format: :js
        end.to change(Event, :count).by(1)
        expect(assigns(:event).company_id).to eq(company.id)
      end

      it 'should assign users to the new event', :inline_jobs do
        company_user.update_attributes(
          notifications_settings: %w(new_event_team_sms new_event_team_email),
          user_attributes: { phone_number_verified: true })
        expect(UserMailer).to receive(:notification)
          .with(company_user.id, 'Added to Event',
                %r{You have been added to a new event:<br /><br /> #{campaign.name}<br /> THU May 21, 2020 - FRI May 22, 2020 from 12:00 PM to 1:00 PM<br /> <br /> http:\/\/localhost:5100\/events\/[0-9]+})
          .and_return(double(deliver: true))
        expect do
          expect do
            post 'create', event: {
              campaign_id: campaign.id, team_members: ["company_user:#{company_user.id}"],
              start_date: '05/21/2020', start_time: '12:00pm', end_date: '05/22/2020',
              end_time: '01:00pm' }, format: :js
          end.to change(Event, :count).by(1)
        end.to change(Membership, :count).by(1)
        expect(assigns(:event).users.last.user.id).to eq(user.id)
        open_last_text_message_for user.phone_number
        expect(current_text_message).to have_body "You have a new event http://localhost:5100/events/#{Event.last.id}"
      end

      it 'should create the event with the correct dates' do
        expect do
          xhr :post, 'create', event: {
            campaign_id: campaign.id, start_date: '05/21/2020', start_time: '12:00pm',
            end_date: '05/21/2020', end_time: '01:00pm' }, format: :js
        end.to change(Event, :count).by(1)
        event = Event.last
        expect(event.start_at).to eq(Time.zone.parse('2020/05/21 12:00pm'))
        expect(event.end_at).to eq(Time.zone.parse('2020/05/21 01:00pm'))
        expect(event.promo_hours).to eq(1)
      end

      it 'should create the event with the given event team' do
        user = create(:company_user, company: company)
        team = create(:team, company: company)
        expect do
          post 'create', event: {
            campaign_id: campaign.id, team_members: ["company_user:#{user.id}", "team:#{team.id}"],
            start_date: '05/21/2020', start_time: '12:00pm', description: 'some description',
            end_date: '05/21/2020', end_time: '01:00pm' }, format: :js
        end.to change(Event, :count).by(1)
        event = Event.last
        expect(event.start_at).to eq(Time.zone.parse('2020/05/21 12:00pm'))
        expect(event.end_at).to eq(Time.zone.parse('2020/05/21 01:00pm'))
        expect(event.description).to eq('some description')
        expect(event.promo_hours).to eq(1)
        expect(event.users.to_a).to eql [user]
        expect(event.teams.to_a).to eql [team]
      end
    end

    describe "PUT 'update'" do
      let(:campaign) { create(:campaign, company: company) }
      let(:event) { create(:event, company: company, campaign: campaign) }
      it 'must update the event attributes' do
        new_campaign = create(:campaign, company: company)
        xhr :put, 'update', id: event.to_param, event: {
          campaign_id: new_campaign.id,
          start_date: '05/21/2020', start_time: '12:00pm',
          end_date: '05/22/2020', end_time: '01:00pm' }, format: :js
        expect(assigns(:event)).to eq(event)
        expect(response).to be_success
        event.reload
        expect(event.campaign_id).to eq(new_campaign.id)
        expect(event.start_at).to eq(Time.zone.parse('2020-05-21 12:00:00'))
        expect(event.end_at).to eq(Time.zone.parse('2020-05-22 13:00:00'))
      end

      it 'must update the event attributes' do
        xhr :put, 'update', id: event.to_param, partial: 'event_data', event: {
          campaign_id: create(:campaign, company: company).to_param,
          start_date: '05/21/2020', start_time: '12:00pm',
          end_date: '05/22/2020', end_time: '01:00pm'
        }, format: :js
        expect(assigns(:event)).to eq(event)
        expect(response).to be_success
        expect(response).to render_template('_results_event_data')

        # Test papertrail
        expect(event.versions.count).to eql 2
        expect(event.versions.last.reify.campaign_id).to eql campaign.id
        expect(event.versions.last.whodunnit).to eql user.id.to_s
      end

      it 'should update the event data for a event without data' do
        Kpi.create_global_kpis
        campaign.assign_all_global_kpis
        expect do
          put 'update', id: event.to_param, results_version: event.results_version,
                        event: {
                          results_attributes: {
                            '0' => { form_field_id: campaign.form_field_for_kpi(Kpi.impressions),
                                     value: '100' },
                            '1' => { form_field_id: campaign.form_field_for_kpi(Kpi.interactions),
                                     value: '200' }
                          }
                        }
        end.to change(FormFieldResult, :count).by(2)
        event.reload
        expect(event.result_for_kpi(Kpi.impressions).value).to eq('100')
        expect(event.result_for_kpi(Kpi.interactions).value).to eq('200')
      end

      it 'renders results_version_changed template if no results version was given' do
        field = create(:form_field_text_area, fieldable: campaign)
        event.update_attributes(results_version: 1)
        expect do
          put 'update', id: event.to_param,
                        event: {
                          results_attributes: {
                            '0' => { form_field_id: field.id, value: '100' }
                          }
                        }
        end.to_not change(FormFieldResult, :count)
        expect(response).to render_template 'results_version_changed'
      end

      it 'renders results_version_changed template if the given results_version is different than the stored' do
        field = create(:form_field_text_area, fieldable: campaign)
        event.update_attributes(results_version: 1)
        expect do
          put 'update', id: event.to_param,
                        event: {
                          results_attributes: {
                            '0' => { form_field_id: field.id, value: '100' }
                          }
                        },
                        results_version: event.results_version + 1
        end.to_not change(FormFieldResult, :count)
        expect(response).to render_template 'results_version_changed'
      end

      it 'should update the event data for a event that already have results' do
        Kpi.create_global_kpis
        campaign.assign_all_global_kpis

        impressions = event.result_for_kpi(Kpi.impressions)
        interactions = event.result_for_kpi(Kpi.interactions)
        expect do
          event.result_for_kpi(Kpi.impressions).value = '100'
          event.result_for_kpi(Kpi.interactions).value = '200'
          event.save
        end.to change(FormFieldResult, :count).by(2)

        expect do
          put 'update', id: event.to_param, results_version: event.results_version,
                        event: {
                          results_attributes: {
                            '0' => { form_field_id: campaign.form_field_for_kpi(Kpi.impressions),
                                     kpi_id: Kpi.impressions.id, kpis_segment_id: nil,
                                     value: '1111', id: impressions.id },
                            '1' => { form_field_id: campaign.form_field_for_kpi(Kpi.interactions),
                                     kpi_id: Kpi.interactions.id, kpis_segment_id: nil,
                                     value: '2222', id: interactions.id }
                          }
                        }
        end.to_not change(FormFieldResult, :count)
        event.reload
        expect(event.result_for_kpi(Kpi.impressions).value).to eq('1111')
        expect(event.result_for_kpi(Kpi.interactions).value).to eq('2222')
      end
    end

    describe "DELETE 'delete_member' with a user" do
      let(:event) { create(:event, company: company) }
      it 'should remove the team member from the event' do
        event.users << company_user
        expect do
          delete 'delete_member', id: event.id, member_id: company_user.id, format: :js
          expect(response).to be_success
          expect(assigns(:event)).to eq(event)
          event.reload
        end.to change(event.users, :count).by(-1)
      end

      it 'should unassign any tasks assigned the user' do
        event.users << company_user
        other_user = create(:company_user, company_id: 1)
        user_tasks = create_list(:task, 3, event: event, company_user: company_user)
        other_tasks = create_list(:task, 2, event: event, company_user: other_user)
        delete 'delete_member', id: event.id, member_id: company_user.id, format: :js

        user_tasks.each { |t| expect(t.reload.company_user_id).to be_nil }
        other_tasks.each { |t| expect(t.reload.company_user_id).not_to be_nil }
      end

      it "should not raise error if the user doesn't belongs to the event" do
        delete 'delete_member', id: event.id, member_id: company_user.id, format: :js
        event.reload
        expect(response).to be_success
        expect(assigns(:event)).to eq(event)
      end
    end

    describe "DELETE 'delete_member' with a team" do
      let(:event) { create(:event, company: company) }
      let(:team) { create(:team, company: company) }
      it 'should remove the team from the event' do
        event.teams << team
        expect do
          delete 'delete_member', id: event.id, team_id: team.id, format: :js
          expect(response).to be_success
          expect(assigns(:event)).to eq(event)
          event.reload
        end.to change(event.teams, :count).by(-1)
      end

      it 'should unassign any tasks assigned the team users' do
        another_user = create(:company_user, company: company)
        team.users << another_user
        event.teams << team
        other_user = create(:company_user, company_id: 1)
        user_tasks = create_list(:task, 3, event: event, company_user: another_user)
        other_tasks = create_list(:task, 2, event: event, company_user: other_user)
        delete 'delete_member', id: event.id, team_id: team.id, format: :js
        event.reload
        user_tasks.each { |t| expect(t.reload.company_user_id).to be_nil }
        other_tasks.each { |t| expect(t.reload.company_user_id).not_to be_nil }
      end

      it 'should not unassign any tasks assigned the team users if the user is directly assigned to the event' do
        team.users << company_user
        event.teams << team
        event.users << company_user
        other_user = create(:company_user, company: company)
        user_tasks = create_list(:task, 3, event: event, company_user: company_user)
        other_tasks = create_list(:task, 2, event: event, company_user: other_user)
        delete 'delete_member', id: event.id, team_id: team.id, format: :js

        user_tasks.each { |t| expect(t.reload.company_user_id).to eq(company_user.id) }
        other_tasks.each { |t| expect(t.reload.company_user_id).not_to be_nil }
      end

      it "should not raise error if the team doesn't belongs to the event" do
        delete 'delete_member', id: event.id, team_id: team.id, format: :js
        event.reload
        expect(response).to be_success
        expect(assigns(:event)).to eq(event)
      end
    end

    describe "GET 'new_member" do
      let(:event) { create(:event, company: company) }
      it 'should load all the company\'s users into users' do
        create(:user, company_id: company.id + 1)
        another_user = create(:company_user, company_id: company.id, role_id: company_user.role_id)
        xhr :get, 'new_member', id: event.id, format: :js
        event.reload
        expect(response).to be_success
        expect(assigns(:event)).to eq(event)
        expect(assigns(:staff)).to match_array [
          { 'id' => company_user.id.to_s, 'name' => company_user.full_name,
            'description' => 'Super Admin', 'type' => 'user' },
          { 'id' => another_user.id.to_s, 'name' => 'Test User',
            'description' => 'Super Admin', 'type' => 'user' }
        ]
      end

      it 'should not load the users that are already assigned to the event' do
        another_user = create(:company_user, company_id: company.id, role_id: company_user.role_id)
        event.users << company_user
        xhr :get, 'new_member', id: event.id, format: :js
        expect(response).to be_success
        expect(assigns(:event)).to eq(event)
        expect(assigns(:staff).to_a).to eq([
          { 'id' => another_user.id.to_s, 'name' => 'Test User',
            'description' => 'Super Admin', 'type' => 'user' }])
      end

      it 'should load teams with active users' do
        event.users << company_user
        company_user.user.update_attributes(first_name: 'CDE', last_name: 'FGH')
        team = create(:team, name: 'ABC', description: 'A sample team', company_id: company.id)
        other_user = create(:company_user, company_id: company.id, role_id: company_user.role_id)
        team.users << other_user
        xhr :get, 'new_member', id: event.id, format: :js
        expect(assigns(:assignable_teams)).to eq([team])
        expect(assigns(:staff).to_a).to eq([
          { 'id' => team.id.to_s, 'name' => 'ABC', 'description' => 'A sample team', 'type' => 'team' },
          { 'id' => other_user.id.to_s, 'name' => 'Test User', 'description' => 'Super Admin', 'type' => 'user' }
        ])
      end
    end

    describe "POST 'add_members" do
      let(:place) { create(:place) }
      let(:event) { create(:event, company: company, place: place) }

      it 'should assign the user to the event and create a notification for the new member' do
        other_user = create(:company_user, company_id: company.id)
        other_user.places << place
        expect do
          expect do
            xhr :post, 'add_members', id: event.id, new_members: ["user_#{other_user.to_param}"], format: :js
            expect(response).to be_success
            expect(assigns(:event)).to eq(event)
            event.reload
          end.to change(event.users, :count).by(1)
        end.to change(other_user.notifications, :count).by(1)
        expect(event.users).to match_array([other_user])
        other_user.reload
        notification = other_user.notifications.last
        expect(notification.company_user_id).to eq(other_user.id)
        expect(notification.message).to eq('new_event')
        expect(notification.path).to eq(event_path(event))
      end

      it 'should assign all the team to the event and create a notification for team members' do
        team = create(:team, company_id: company.id)
        other_user = create(:company_user, company_id: company.id)
        other_user.places << place
        team.users << other_user
        expect do
          expect do
            xhr :post, 'add_members', id: event.id, new_members: ["team_#{team.to_param}"], format: :js
            expect(response).to be_success
            expect(assigns(:event)).to eq(event)
            event.reload
          end.to change(event.teams, :count).by(1)
        end.to change(other_user.notifications, :count).by(1)
        expect(event.teams).to eq([team])
        other_user.reload
        notification = other_user.notifications.last
        expect(notification.company_user_id).to eq(other_user.id)
        expect(notification.message).to eq('new_team_event')
        expect(notification.path).to eq(event_path(event))
      end

      it 'should not assign users to the event if they are already part of the event' do
        event.users << company_user
        expect do
          xhr :post, 'add_members', id: event.id, new_members: ["user_#{company_user.to_param}"], format: :js
          expect(response).to be_success
          expect(assigns(:event)).to eq(event)
          event.reload
        end.not_to change(event.users, :count)
      end

      it 'should not assign teams to the event if they are already part of the event' do
        team = create(:team, company_id: company.id)
        event.teams << team
        expect do
          xhr :post, 'add_members', id: event.id, new_members: ["team_#{team.to_param}"], format: :js
          expect(response).to be_success
          expect(assigns(:event)).to eq(event)
          event.reload
        end.not_to change(event.teams, :count)
      end
    end

    describe "GET 'activate'" do
      it 'should activate an inactive event' do
        event = create(:event, active: false, company: company)
        expect do
          xhr :get, 'activate', id: event.to_param, format: :js
          expect(response).to be_success
          event.reload
        end.to change(event, :active).to(true)
      end
    end

    describe "GET 'deactivate'" do
      it 'should deactivate an active event' do
        event = create(:event, active: true, company: company)
        expect do
          xhr :get, 'deactivate', id: event.to_param, format: :js
          expect(response).to be_success
          event.reload
        end.to change(event, :active).to(false)
      end
    end

    describe "PUT 'submit'" do
      it 'should submit event', :search, :inline_jobs do
        event = create(:event, active: true, company: company)
        company_user.update_attributes(
          notifications_settings: %w(event_recap_pending_approval_sms event_recap_pending_approval_email),
          user_attributes: { phone_number_verified: true })
        event.users << company_user
        message = "You have an event recap that is pending approval http://localhost:5100/events/#{event.id}"
        expect(UserMailer).to receive(:notification)
          .with(company_user.id, 'Event Recaps Pending Approval', message)
          .and_return(double(deliver: true))
        expect do
          xhr :put, 'submit', id: event.to_param, format: :js
          expect(response).to be_success
          event.reload
        end.to change(event, :submitted?).to(true)
        open_last_text_message_for user.phone_number
        expect(current_text_message).to have_body message
      end

      it 'should not allow to submit the event if the event data is not valid' do
        campaign = create(:campaign, company_id: company)
        create(:form_field_number, fieldable: campaign,
                                   kpi: create(:kpi, company_id: 1), required: true)
        event = create(:event, active: true, company: company, campaign: campaign)
        expect do
          xhr :put, 'submit', id: event.to_param, format: :js
          expect(response).to be_success
          event.reload
        end.to_not change(event, :submitted?)
      end
    end

    describe "PUT 'approve'" do
      it 'should approve event' do
        event = create(:submitted_event, active: true, company: company)
        expect do
          put 'approve', id: event.to_param
          expect(response).to redirect_to(event_path(event, status: 'approved'))
          event.reload
        end.to change(event, :approved?).to(true)
      end
    end

    describe "PUT 'unapprove'" do
      it 'should unapprove event' do
        event = create(:approved_event, active: true, company: company)
        expect do
          put 'unapprove', id: event.to_param
          expect(response).to redirect_to(event_path(event, status: 'unapproved'))
          event.reload
        end.to change(event, :submitted?).to(true)
      end
    end

    describe "PUT 'reject'" do
      it 'should reject event', :search, :inline_jobs do
        Timecop.freeze do
          event = create(:submitted_event, active: true, company: company)
          company_user.update_attributes(
            notifications_settings: %w(event_recap_rejected_sms event_recap_rejected_email),
            user_attributes: { phone_number_verified: true })
          event.users << company_user
          message = "You have a rejected event recap http://localhost:5100/events/#{event.id}"
          expect(UserMailer).to receive(:notification)
            .with(company_user.id, 'Rejected Event Recaps', message)
            .and_return(double(deliver: true))
          expect do
            xhr :put, 'reject', id: event.to_param, reason: 'blah blah blah', format: :js
            expect(response).to be_success
            event.reload
          end.to change(event, :rejected?).to(true)
          expect(event.reject_reason).to eq('blah blah blah')
          open_last_text_message_for user.phone_number
          expect(current_text_message).to have_body message
        end
      end
    end
  end

  describe 'user with permissions to edit event data only' do
    let(:company_user) do
      create(:company_user, company_id: create(:company).id,
                            permissions: [[:show, 'Event'], [:edit_unsubmitted_data, 'Event']])
    end
    let(:user) { company_user.user }
    let(:company) { company_user.company }
    let(:event) { create(:event, company: company) }

    before { sign_in user }

    it 'should be able to edit event_data' do
      xhr :put, 'update', id: event.to_param, results_version: event.results_version,
                          event: { results_attributes: {} }, format: :js
      expect(assigns(:event)).to eq(event)
      expect(response).to be_success
      expect(response).to render_template('events/_event')
    end
  end
end
