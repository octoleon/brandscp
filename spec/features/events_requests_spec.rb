require 'rails_helper'

feature 'Events section' do
  let(:company) { create(:company) }
  let(:campaign) { create(:campaign, company: company, name: 'Campaign FY2012', brands: [brand]) }
  let(:user) { create(:user, company: company, role_id: role.id) }
  let(:company_user) { user.company_users.first }
  let(:place) { create(:place, name: 'A Nice Place', country: 'CR', city: 'Curridabat', state: 'San Jose') }
  let(:permissions) { [] }
  let(:event) { create(:event, campaign: campaign, company: company) }
  let(:brand) { create(:brand, company: company, name: 'My Kool Brand') }
  let(:venue) { create(:venue, place: place, company: company) }

  before do
    Warden.test_mode!
    add_permissions permissions
    sign_in user
  end

  after { Warden.test_reset! }

  shared_examples_for 'a user that can activate/deactivate events' do
    let(:events)do
      [
        create(:event, start_date: '08/21/2013', end_date: '08/21/2013',
                       start_time: '10:00am', end_time: '11:00am', campaign: campaign, place: place),
        create(:event, start_date: '08/28/2013', end_date: '08/29/2013',
                       start_time: '11:00am', end_time: '12:00pm', campaign: campaign, place: place)
      ]
    end
    scenario 'should allow user to deactivate events from the event list' do
      Timecop.travel(Time.zone.local(2013, 07, 30, 12, 01)) do
        events  # make sure events are created before
        Sunspot.commit
        visit events_path

        expect(page).to have_selector event_list_item(events.first)
        within resource_item events.first do
          click_js_button 'Deactivate Event'
        end

        confirm_prompt 'Are you sure you want to deactivate this event?'

        expect(page).to have_no_selector event_list_item(events.first)
      end
    end

    scenario 'should allow user to activate events' do
      Timecop.travel(Time.zone.local(2013, 07, 21, 12, 01)) do
        events.each(&:deactivate!) # Deactivate the events
        Sunspot.commit

        visit events_path

        # Show only inactive items
        add_filter('ACTIVE STATE', 'Inactive')
        remove_filter('Active')

        expect(page).to have_selector event_list_item(events.first)
        within resource_item events.first do
          click_js_button 'Activate Event'
        end
        expect(page).to have_no_selector event_list_item(events.first)
      end
    end

    scenario 'allows the user to activate/deactivate a event from the event details page' do
      visit event_path(events.first)
      within('.edition-links') do
        click_js_button 'Deactivate Event'
      end

      confirm_prompt 'Are you sure you want to deactivate this event?'

      within('.edition-links') do
        click_js_button('Activate Event')
        expect(page).to have_button('Deactivate Event') # test the link have changed
      end
    end
  end

  feature 'non admin user', js: true, search: true do
    let(:role) { create(:non_admin_role, company: company) }

    it_should_behave_like 'a user that can activate/deactivate events' do
      before { company_user.campaigns << campaign }
      before { company_user.places << create(:place, city: nil, state: 'San Jose', country: 'CR', types: ['locality']) }
      let(:permissions) { [[:index, 'Event'], [:view_list, 'Event'], [:deactivate, 'Event'],
                           [:show, 'Event'], [:view_members, 'Event'], [:add_members, 'Event']] }
    end
  end

  feature 'admin user', js: true, search: true do
    let(:role) { create(:role, company: company) }

    it_behaves_like 'a user that can activate/deactivate events'

    feature '/events', js: true, search: true  do
      after do
        Timecop.return
      end

      feature 'Close bar' do
        scenario 'clicking the return button should preserve the filter tags' do
          create(:submitted_event, campaign: campaign)
          Sunspot.commit
          visit events_path

          add_filter 'EVENT STATUS', 'Submitted'
          add_filter 'EVENT STATUS', 'Approved'
          remove_filter 'Today To The Future'

          within resource_item(1) do
            click_js_link 'Event Details'
          end

          close_resource_details
          expect(collection_description).to have_filter_tag 'Submitted'
          expect(collection_description).to have_filter_tag 'Approved'
          expect(collection_description).to_not have_filter_tag 'Today To The Future'
        end
      end

      feature 'GET index' do
        let(:today) { Time.zone.local(Time.now.year, Time.now.month, Time.now.day, 12, 00) }
        let(:events) do
          [
            create(:event,
                   start_date: '08/21/2013', end_date: '08/21/2013',
                   start_time: '10:00am', end_time: '11:00am',
                   campaign: campaign, active: true,
                   place: create(:place, name: 'Place 1')),
            create(:event,
                   start_date: '08/28/2013', end_date: '08/29/2013',
                   start_time: '11:00am', end_time: '12:00pm',
                   campaign: create(:campaign, name: 'Another Campaign April 03', company: company),
                   place: create(:place, name: 'Place 2'), company: company)
          ]
        end

        scenario 'a user can play and dismiss the video tutorial' do
          visit events_path

          feature_name = 'GETTING STARTED: EVENTS'

          expect(page).to have_selector('h5', text: feature_name)
          expect(page).to have_content('The Events module is your one-stop-shop')
          click_link 'Play Video'
          wait_for_ajax(90)

          within visible_modal do
            click_js_link 'Close'
          end
          ensure_modal_was_closed

          within('.new-feature') do
            click_js_link 'Dismiss'
          end
          wait_for_ajax

          visit events_path
          expect(page).to have_no_selector('h5', text: feature_name)
        end

        scenario 'should display a list of events' do
          Timecop.travel(Time.zone.local(2013, 07, 21, 12, 01)) do
            events # make sure events are created before
            create(:event,
                   start_date: '08/30/2013', end_date: '08/30/2013',
                   start_time: '10:00am', end_time: '12:00pm',
                   company: company, campaign: campaign,
                   place: create(:place, name: 'Merged Place', merged_with_place_id: venue.place.id))
            create(:custom_filter,
                   owner: company_user, name: 'My Venues Filter', apply_to: 'events',
                   filters: "status%5B%5D=Active&venue%5B%5D=#{venue.id}")

            Sunspot.commit
            visit events_path

            within('#events-list') do
              # First Row
              within resource_item 1 do
                expect(page).to have_content('WED Aug 21')
                expect(page).to have_content('10:00 AM - 11:00 AM')
                expect(page).to have_content(events[0].place_name)
                expect(page).to have_content('Campaign FY2012')
              end
              # Second Row
              within resource_item 2 do
                expect(page).to have_content(events[1].start_at.strftime('WED Aug 28 at 11:00 AM'))
                expect(page).to have_content(events[1].end_at.strftime('THU Aug 29 at 12:00 PM'))
                expect(page).to have_content(events[1].place_name)
                expect(page).to have_content('Another Campaign April 03')
              end
              # Third Row
              within resource_item 3 do
                expect(page).to have_content('FRI Aug 30')
                expect(page).to have_content('10:00 AM - 12:00 PM')
                expect(page).to have_content(venue.place.name)
                expect(page).to have_content('Campaign FY2012')
              end
            end

            # Filter by venue should display the results including the activity with the merged place
            select_saved_filter 'My Venues Filter'

            within('#events-list') do
              # First Row
              within resource_item 1 do
                expect(page).to have_content('FRI Aug 30')
                expect(page).to have_content('10:00 AM - 12:00 PM')
                expect(page).to have_content(venue.place.name)
                expect(page).to have_content('Campaign FY2012')
              end

              # Events with different venue/place should not be displayed
              expect(page).to_not have_content('10:00 AM - 11:00 AM')
              expect(page).to_not have_content('WED Aug 28 at 11:00 AM')
            end
          end
        end


        scenario 'should display a list of events with users assoicated with event' do
          ev1 = create(:event,
                       campaign: create(:campaign, name: 'Campaña1', company: company))
          ev2 = create(:event,
                       campaign: create(:campaign, name: 'Campaña2', company: company))
          ev1.users << create(:company_user,
                              user: create(:user, first_name: 'Roberto', last_name: 'Gomez'),
                              company: company)
          ev2.users << create(:company_user,
                              user: create(:user, first_name: 'Cristiano', last_name: 'Ronaldo'),
                              company: company)
          ev2.users << create(:company_user,
                              user: create(:user, first_name: 'Lionel', last_name: 'Messi'),
                              company: company)
          ev2.users << create(:company_user,
                              user: create(:user, first_name: 'Luis', last_name: 'Suarez'),
                              company: company)
          ev2.users << create(:company_user,
                              user: create(:user, first_name: 'Mario', last_name: 'Cantinflas'),
                              company: company)
          Sunspot.commit

          visit events_path
          # First Row
          within resource_item 1 do
            expect(page).to have_content('RG')
          end
          # Second Row
          within resource_item 2  do
            expect(page).to have_content('CR')
            expect(page).to have_content('LS')
            expect(page).to have_content('LM')
          end

          #have +1 more in second row
          within resource_item 2  do
            expect(page).to have_content('+1 more')
            #click '+1 more...'
            click_js_link '+1 more...'
            expect(page).to have_content('Mario Cantinflas')
            click_js_link '+1 more...'
            expect(page).not_to have_content('Mario Cantinflas')
          end

        end

        scenario 'should not display events from deactivated campaigns' do
          Timecop.travel(Time.zone.local(2013, 07, 21, 12, 01)) do
            events # make sure events are created before
            Sunspot.commit

            visit events_path

            within events_list do
              expect(page).to have_content('Campaign FY2012')
              expect(page).to have_content('Another Campaign April 03')
            end

            campaign.update_attribute(:aasm_state, 'inactive')
            Sunspot.commit

            visit events_path

            within events_list do
              expect(page).to have_no_content('Campaign FY2012')
              expect(page).to have_content('Another Campaign April 03')
            end
          end
        end

        scenario 'user can remove the date filter tag' do
          place = create(:place, name: 'Place 1', city: 'Los Angeles', state: 'CA', country: 'US')
          create(:late_event, campaign: campaign, place: place)
          Sunspot.commit

          visit events_path

          expect(page).to have_content('0 events found for: Active Today To The Future')

          expect(collection_description).to have_filter_tag('Today To The Future')
          remove_filter 'Today To The Future'

          expect(page).to have_content('1 event found for: Active')
          expect(collection_description).not_to have_filter_tag('Today To The Future')

          within resource_item do
            expect(page).to have_content(campaign.name)
          end
        end

        scenario 'user can filter events by several statuses' do
          place = create(:place, name: 'Place 1', city: 'Los Angeles', state: 'CA', country: 'US')
          create(:rejected_event,
                 start_date: (today - 4.days).to_s(:slashes), end_date: (today - 4.days).to_s(:slashes),
                 campaign: campaign, active: true,
                 place: place)
          create(:event,
                 start_date: (today + 4.days).to_s(:slashes), end_date: (today + 4.days).to_s(:slashes),
                 campaign: campaign, active: true,
                 place: place)
          Sunspot.commit

          visit events_path

          expect(page).to have_content('1 event found for: Active Today To The Future')

          expect(collection_description).to have_filter_tag('Today To The Future')
          remove_filter 'Today To The Future'

          expect(page).to have_content('2 events found for: Active')
          expect(collection_description).not_to have_filter_tag('Today To The Future')

          add_filter 'EVENT STATUS', 'Scheduled'

          expect(collection_description).to have_filter_tag('Scheduled')
          expect(page).to have_content('1 event found for: Active Scheduled')

          add_filter 'EVENT STATUS', 'Rejected'

          expect(collection_description).to have_filter_tag('Scheduled')
          expect(page).to have_content('2 events found for: Active Rejected Scheduled')
        end

        scenario 'event should not be removed from the list when deactivated' do
          place = create(:place, name: 'Place 1', city: 'Los Angeles', state: 'CA', country: 'US')
          create(:event, campaign: campaign, place: place)
          Sunspot.commit

          visit events_path

          expect(page).to have_content('1 event found for: Active Today To The Future')
          add_filter 'ACTIVE STATE', 'Inactive'

          within resource_item do
            click_js_button 'Deactivate Event'
          end
          confirm_prompt 'Are you sure you want to deactivate this event?'

          expect(page).to have_button 'Activate Event'

          within resource_item do
            click_js_button 'Activate Event'
          end

          expect(page).to have_button 'Deactivate Event'

          remove_filter 'Inactive'
          within(events_list) { expect(page).to have_content(campaign.name) }
          within resource_item do
            click_js_button 'Deactivate Event'
          end
          confirm_prompt 'Are you sure you want to deactivate this event?'

          within(events_list) { expect(page).not_to have_content(campaign.name) }

          remove_filter 'Active'
          within(events_list) { expect(page).to have_content(campaign.name) }
        end

        scenario 'should allow allow filter events by date range selected from the calendar' do
          today = Time.zone.local(2015, 1, 18, 12, 00)
          tomorrow = today + 1.day
          Timecop.travel(today) do
            create(:event,
                   start_date: today.to_s(:slashes), end_date: today.to_s(:slashes),
                   start_time: '10:00am', end_time: '11:00am', campaign: campaign,
                   place: create(:place, name: 'Place 1', city: 'Los Angeles', state: 'CA', country: 'US'))
            create(:event,
                   start_date: tomorrow.to_s(:slashes), end_date: tomorrow.to_s(:slashes),
                   start_time: '11:00am',  end_time: '12:00pm',
                   campaign: create(:campaign, name: 'Another Campaign April 03', company: company),
                   place: create(:place, name: 'Place 2', city: 'Austin', state: 'TX', country: 'US'))
            Sunspot.commit

            visit events_path

            expect(page).to have_content('2 events found for: Active Today To The Future')

            within events_list do
              expect(page).to have_content('Campaign FY2012')
              expect(page).to have_content('Another Campaign April 03')
            end

            expect(page).to have_filter_section(title: 'CAMPAIGNS',
                                                options: ['Campaign FY2012', 'Another Campaign April 03'])
            # expect(page).to have_filter_section(title: 'LOCATIONS', options: ['Los Angeles', 'Austin'])

            add_filter 'CAMPAIGNS', 'Campaign FY2012'

            expect(page).to have_content('1 event found for: Active Today To The Future Campaign FY2012')

            within events_list do
              expect(page).to have_no_content('Another Campaign April 03')
              expect(page).to have_content('Campaign FY2012')
            end

            add_filter 'CAMPAIGNS', 'Another Campaign April 03'
            within events_list do
              expect(page).to have_content('Another Campaign April 03')
              expect(page).to have_content('Campaign FY2012')
            end

            expect(page).to have_content('2 events found for: Active Today To The Future Another Campaign April 03 Campaign FY2012')

            select_filter_calendar_day('18')
            within events_list do
              expect(page).to have_no_content('Another Campaign April 03')
              expect(page).to have_content('Campaign FY2012')
            end

            expect(page).to have_content('1 event found for: Active Today Another Campaign April 03 Campaign FY2012')

            select_filter_calendar_day('18', '19')
            expect(page).to have_content(
              '2 events found for: Active Today - Tomorrow Another Campaign April 03 Campaign FY2012'
            )
            within events_list do
              expect(page).to have_content('Another Campaign April 03')
              expect(page).to have_content('Campaign FY2012')
            end
          end
        end

        feature 'export' do
          let(:month_number) { today.strftime('%m') }
          let(:month_name) { today.strftime('%b') }
          let(:year_number) { today.strftime('%Y').to_i }
          let(:today) { Time.use_zone(user.time_zone) { Time.current } }
          let!(:event1) do
            create(:event, start_date: today.to_s(:slashes), end_date: today.to_s(:slashes),
                           start_time: '10:00am', end_time: '11:00am',
                           campaign: campaign, active: true,
                           place: create(:place, name: 'Place 1'))
          end
          let!(:event2) do
            create(:event, start_date: today.to_s(:slashes), end_date: today.to_s(:slashes),
                           start_time: '08:00am', end_time: '09:00am',
                           campaign: create(:campaign, name: 'Another Campaign April 03', company: company),
                           place: create(:place, name: 'Place 2', city: 'Los Angeles',
                                                 state: 'CA', zipcode: '67890'))
          end

          before { Sunspot.commit }

          scenario 'should be able to export as CSV' do
            contact1 = create(:contact, first_name: 'Guillermo', last_name: 'Vargas', email: 'guilleva@gmail.com', company: company)
            contact2 = create(:contact, first_name: 'Chris', last_name: 'Jaskot', email: 'cjaskot@gmail.com', company: company)
            create(:contact_event, event: event1, contactable: contact1)
            create(:contact_event, event: event1, contactable: contact2)
            Sunspot.commit

            visit events_path

            click_js_link 'Download'
            click_js_link 'Download as CSV'

            wait_for_export_to_complete

            expect(ListExport.last).to have_rows([
              ['CAMPAIGN NAME', 'AREA', 'START', 'END', 'DURATION', 'VENUE NAME', 'ADDRESS', 'CITY',
               'STATE', 'ZIP','EVENT DESCRIPTION', 'ACTIVE STATE', 'EVENT STATUS', 'TEAM MEMBERS', 'CONTACTS', 'URL'],
              ['Another Campaign April 03', '', "#{year_number}-#{month_number}-#{today.strftime('%d')} 08:00",
               "#{year_number}-#{month_number}-#{today.strftime('%d')} 09:00", '1.00', 'Place 2',
               'Place 2, 11 Main St., Los Angeles, CA, 67890', 'Los Angeles', 'CA', '67890', nil, 'Active', 'Unsent',
               '', '', "http://#{Capybara.current_session.server.host}:#{Capybara.current_session.server.port}/events/#{event2.id}"],
              ['Campaign FY2012', '', "#{year_number}-#{month_number}-#{today.strftime('%d')} 10:00",
               "#{year_number}-#{month_number}-#{today.strftime('%d')} 11:00", '1.00', 'Place 1',
               'Place 1, 11 Main St., New York City, NY, 12345', 'New York City', 'NY', '12345', nil,'Active',
               'Unsent', '', 'Chris Jaskot, Guillermo Vargas',
               "http://#{Capybara.current_session.server.host}:#{Capybara.current_session.server.port}/events/#{event1.id}"]
            ])
          end

          scenario 'should be able to export as PDF' do
            visit events_path

            click_js_link 'Download'
            click_js_link 'Download as PDF'

            wait_for_export_to_complete

            # Test the generated PDF...
            reader = PDF::Reader.new(open(ListExport.last.file.url))
            reader.pages.each do |page|
              # PDF to text seems to not always return the same results
              # with white spaces, so, remove them and look for strings
              # without whitespaces
              text = page.text.gsub(/[\s\n]/, '')
              expect(text).to include '2eventsfoundfor'
              expect(text).to include 'CampaignFY2012'
              expect(text).to include 'AnotherCampaignApril03'
              expect(text).to include 'NewYorkCity,NY,12345'
              expect(text).to include 'LosAngeles,CA,67890'
              expect(text).to include '10:00AM-11:00AM'
              expect(text).to include '8:00AM-9:00AM'
              expect(text).to match(/#{month_name}#{today.strftime('%-d')}/)
            end
          end

          scenario 'should be able to export the calendar view as PDF' do
            visit events_path

            click_link 'Calendar View'

            expect(find('.calendar-table')).to have_text 'My Kool Brand'

            click_js_link 'Download'
            click_js_link 'Download as PDF'

            wait_for_export_to_complete

            # Test the generated PDF...
            reader = PDF::Reader.new(open(ListExport.last.file.url))
            reader.pages.each do |page|
              # PDF to text seems to not always return the same results
              # with white spaces, so, remove them and look for strings
              # without whitespaces
              text = page.text.gsub(/[\s\n]/, '')
              expect(text).to include 'MyKool'
              expect(text).to include "#{today.strftime('%B')}#{year_number}"
            end
          end

          scenario 'event list export is limited to 200 pages' do
            allow(Event).to receive(:do_search).and_return(double(total: 3000))

            visit events_path

            click_js_link 'Download'
            click_js_link 'Download as PDF'

            within visible_modal do
              expect(page).to have_content('PDF exports are limited to 200 pages. Please narrow your results and try exporting again.')
              click_js_link 'OK'
            end
            ensure_modal_was_closed
          end
        end

        feature 'date ranges box' do
          let(:today) { Time.zone.local(Time.now.year, Time.now.month, Time.now.day, 12, 00) }
          let(:month_number) { Time.now.strftime('%m').to_i }
          let(:year) { Time.now.strftime('%Y').to_i }
          let(:campaign1) { create(:campaign, name: 'Campaign FY2012', company: company) }
          let(:campaign2) { create(:campaign, name: 'Another Campaign April 03', company: company) }
          let(:campaign3) { create(:campaign, name: 'New Brand Campaign', company: company) }

          scenario "can filter the events by predefined 'Today' date range option" do
            create(:event, start_date: today.to_s(:slashes), end_date: today.to_s(:slashes), campaign: campaign1)
            create(:event, start_date: today.to_s(:slashes), end_date: today.to_s(:slashes), campaign: campaign2)
            create(:event, start_date: (today + 1.day).to_s(:slashes), end_date: (today + 1.day).to_s(:slashes), campaign: campaign3)
            Sunspot.commit

            visit events_path

            choose_predefined_date_range 'Today'
            expect(page).to have_filter_tag('Today')

            expect(page).to have_selector('#events-list .resource-item', count: 2)
            within events_list do
              expect(page).to have_content('Campaign FY2012')
              expect(page).to have_content('Another Campaign April 03')
              expect(page).to have_no_content('New Brand Campaign')
            end
          end

          scenario "can filter the events by predefined 'Current week' date range option" do
            create(:event, start_date: today.to_s(:slashes), end_date: today.to_s(:slashes), campaign: campaign2)
            create(:event, start_date: today.to_s(:slashes), end_date: today.to_s(:slashes), campaign: campaign3)
            create(:event, start_date: (today - 2.weeks).to_s(:slashes), end_date: (today - 2.weeks).to_s(:slashes), campaign: campaign1)
            Sunspot.commit

            visit events_path

            choose_predefined_date_range 'Current week'
            wait_for_ajax

            expect(page).to have_selector('#events-list .resource-item', count: 2)
            within events_list do
              expect(page).to have_no_content('Campaign FY2012')
              expect(page).to have_content('Another Campaign April 03')
              expect(page).to have_content('New Brand Campaign')
            end
          end

          scenario "can filter the events by predefined 'Current month' date range option" do
            create(:event, campaign: campaign3,
                           start_date: "#{month_number}/15/#{year}",
                           end_date: "#{month_number}/15/#{year}")
            create(:event, campaign: campaign2,
                           start_date: "#{month_number}/16/#{year}",
                           end_date: "#{month_number}/16/#{year}")
            create(:event, campaign: campaign1,
                           start_date: "#{(today + 1.month).month}/15/#{(today + 1.month).year}",
                           end_date: "#{(today + 1.month).month}/15/#{(today + 1.month).year}")
            Sunspot.commit

            visit events_path

            choose_predefined_date_range 'Current month'
            expect(page).to have_content('2 events found for:')

            expect(page).to have_selector('#events-list .resource-item', count: 2)
            within events_list do
              expect(page).to have_no_content('Campaign FY2012')
              expect(page).to have_content('Another Campaign April 03')
              expect(page).to have_content('New Brand Campaign')
            end
          end

          scenario "can filter the events by predefined 'Previous week' date range option" do
            create(:event, start_date: today.to_s(:slashes), end_date: today.to_s(:slashes), campaign: campaign2)
            create(:event, start_date: today.to_s(:slashes), end_date: today.to_s(:slashes), campaign: campaign3)
            create(:event, start_date: (today - 1.week).to_s(:slashes), end_date: (today - 1.week).to_s(:slashes), campaign: campaign1)
            Sunspot.commit

            visit events_path

            choose_predefined_date_range 'Previous week'
            expect(page).to have_content('2 events found for:')

            expect(page).to have_selector('#events-list .resource-item', count: 1)
            within events_list do
              expect(page).to have_content('Campaign FY2012')
              expect(page).to have_no_content('Another Campaign April 03')
              expect(page).to have_no_content('New Brand Campaign')
            end
          end

          scenario "can filter the events by predefined 'Previous month' date range option" do
            create(:event, campaign: campaign2,
                           start_date: "#{month_number}/15/#{year}",
                           end_date: "#{month_number}/15/#{year}")
            create(:event, campaign: campaign1,
                           start_date: "#{(today - 1.month).month}/15/#{(today - 1.month).year}",
                           end_date: "#{(today - 1.month).month}/15/#{(today - 1.month).year}")
            create(:event, campaign: campaign1,
                           start_date: "#{(today - 1.month).month}/16/#{(today - 1.month).year}",
                           end_date: "#{(today - 1.month).month}/16/#{(today - 1.month).year}")
            create(:event, campaign: campaign3,
                           start_date: "#{(today - 1.month).month}/17/#{(today - 1.month).year}",
                           end_date: "#{(today - 1.month).month}/17/#{(today - 1.month).year}")
            Sunspot.commit

            visit events_path

            choose_predefined_date_range 'Previous month'
            wait_for_ajax

            expect(page).to have_selector('#events-list .resource-item', count: 3)
            within events_list do
              expect(page).to have_content('Campaign FY2012')
              expect(page).to have_no_content('Another Campaign April 03')
              expect(page).to have_content('New Brand Campaign')
            end
          end

          scenario "can filter the events by predefined 'YTD' date range option for default YTD configuration" do
            create(:event, campaign: campaign1,
                           start_date: "01/01/#{year}",
                           end_date: "01/01/#{year}")
            create(:event, campaign: campaign1,
                           start_date: "01/01/#{year}",
                           end_date: "01/01/#{year}")
            create(:event, campaign: campaign2,
                           start_date: "01/01/#{year}",
                           end_date: "01/01/#{year}")
            create(:event, campaign: campaign3,
                           start_date: "07/17/#{year - 1}",
                           end_date: "07/17/#{year - 1}")
            Sunspot.commit

            visit events_path

            choose_predefined_date_range 'YTD'
            wait_for_ajax

            expect(page).to have_selector('#events-list .resource-item', count: 3)
            within events_list do
              expect(page).to have_content('Campaign FY2012')
              expect(page).to have_content('Another Campaign April 03')
              expect(page).to have_no_content('New Brand Campaign')
            end
          end

          scenario "can filter the events by predefined 'YTD' date range option where YTD goes from July 1 to June 30" do
            company.update_attribute(:ytd_dates_range, Company::YTD_JULY1_JUNE30)
            user.current_company = company

            create(:event, campaign: campaign1,
                           start_date: "#{month_number}/01/#{year}",
                           end_date: "#{month_number}/01/#{year}")
            create(:event, campaign: campaign1,
                           start_date: "#{month_number}/01/#{year}",
                           end_date: "#{month_number}/01/#{year}")
            create(:event, campaign: campaign3,
                           start_date: "#{month_number}/01/#{year}",
                           end_date: "#{month_number}/01/#{year}")
            Sunspot.commit

            visit events_path

            choose_predefined_date_range 'YTD'
            wait_for_ajax

            expect(page).to have_selector('#events-list .resource-item', count: 3)
            within events_list do
              expect(page).to have_content('Campaign FY2012')
              expect(page).to have_no_content('Another Campaign April 03')
              expect(page).to have_content('New Brand Campaign')
            end
          end

          scenario 'can filter the events by custom date range selecting start and end dates' do
            month_number = today.strftime('%m')
            year_number = today.strftime('%Y')
            create(:event, campaign: campaign1, start_date: "#{month_number}/06/#{year_number}", end_date: "#{month_number}/27/#{year_number}")
            create(:event, campaign: campaign2, start_date: "#{month_number}/23/#{year_number}", end_date: "#{month_number}/23/#{year_number}")
            create(:event, campaign: campaign2, start_date: "#{month_number}/20/#{year_number}", end_date: "#{month_number}/20/#{year_number}")
            create(:event, campaign: campaign3, start_date: "#{month_number}/23/#{year_number}", end_date: "#{month_number}/23/#{year_number}")
            create(:event, campaign: campaign3, start_date: "#{month_number}/25/#{year_number}", end_date: "#{month_number}/25/#{year_number}")
            create(:event, campaign: campaign3, start_date: "#{month_number}/26/#{year_number}", end_date: "#{month_number}/26/#{year_number}")
            Sunspot.commit

            visit events_path

            click_js_link 'Date ranges'

            within 'ul.dropdown-menu' do
              expect(page).to have_button('Apply', disabled: true)
              find_field('Start date').click
              select_and_fill_from_datepicker('custom_start_date', "#{month_number}/20/#{year_number}")
              find_field('End date').click
              select_and_fill_from_datepicker('custom_end_date', "#{month_number}/25/#{year_number}")
              expect(page).to have_button('Apply', disabled: false)
              click_js_button 'Apply'
            end
            ensure_date_ranges_was_closed

            expect(page).to have_selector('#events-list .resource-item', count: 5)
            within events_list do
              expect(page).to have_content('Another Campaign April 03')
              expect(page).to have_content('New Brand Campaign')
            end

            # Testing when the user selects a start date after currently selected end date
            click_js_link 'Date ranges'

            within 'ul.dropdown-menu' do
              expect(page).to have_button('Apply', disabled: false)
              find_field('Start date').click
              select_and_fill_from_datepicker('custom_start_date', "#{month_number}/26/#{year_number}")
              expect(find_field('End date').value).to eql "#{month_number}/26/#{year_number}"
              click_js_button 'Apply'
            end
            ensure_date_ranges_was_closed

            expect(page).to have_selector('#events-list .resource-item', count: 2)
            within events_list do
              expect(page).to have_no_content('Another Campaign April 03')
              expect(page).to have_content('New Brand Campaign')
            end
          end
        end

        scenario 'can filter by users' do
          ev1 = create(:event,
                       campaign: create(:campaign, name: 'Campaña1', company: company))
          ev2 = create(:event,
                       campaign: create(:campaign, name: 'Campaña2', company: company))
          ev1.users << create(:company_user,
                              user: create(:user, first_name: 'Roberto', last_name: 'Gomez'),
                              company: company)
          ev2.users << create(:company_user,
                              user: create(:user, first_name: 'Mario', last_name: 'Cantinflas'),
                              company: company)
          Sunspot.commit

          visit events_path

          expect(page).to have_filter_section(
            title: 'PEOPLE',
            options: ['Mario Cantinflas', 'Roberto Gomez', user.full_name])

          within events_list do
            expect(page).to have_content('Campaña1')
            expect(page).to have_content('Campaña2')
          end

          add_filter 'PEOPLE', 'Roberto Gomez'

          within events_list do
            expect(page).to have_content('Campaña1')
            expect(page).to have_no_content('Campaña2')
          end

          remove_filter 'Roberto Gomez'
          add_filter 'PEOPLE', 'Mario Cantinflas'

          within events_list do
            expect(page).to have_content('Campaña2')
            expect(page).to have_no_content('Campaña1')
          end
        end

        scenario 'Filters are preserved upon navigation' do
          today = Time.zone.local(2015, 1, 18, 12, 00)
          tomorrow = today + 1.day
          Timecop.travel(today) do
            ev1 = create(:event, campaign: campaign,
                                 start_date: today.to_s(:slashes), end_date: today.to_s(:slashes),
                                 start_time: '10:00am', end_time: '11:00am',
                                 place: create(:place, name: 'Place 1', city: 'Los Angeles',
                                                       state: 'CA', country: 'US'))

            create(:event,
                   start_date: tomorrow.to_s(:slashes), end_date: tomorrow.to_s(:slashes),
                   start_time: '11:00am',  end_time: '12:00pm',
                   campaign: create(:campaign, name: 'Another Campaign April 03', company: company),
                   place: create(:place, name: 'Place 2', city: 'Austin', state: 'TX', country: 'US'))
            Sunspot.commit

            visit events_path

            add_filter 'CAMPAIGNS', 'Campaign FY2012'
            select_filter_calendar_day('18')

            within events_list do
              click_js_link('Event Details')
            end

            expect(page).to have_selector('h2', text: 'Campaign FY2012')
            expect(current_path).to eq(event_path(ev1))

            close_resource_details

            expect(page).to have_content('1 event found for: Active Today Campaign FY2012')
            expect(current_path).to eq(events_path)

            within events_list do
              expect(page).to have_no_content('Another Campaign April 03')
              expect(page).to have_content('Campaign FY2012')
            end
          end
        end

        scenario 'first filter should keep default filters' do
          Timecop.travel(Time.zone.local(2013, 07, 21, 12, 01)) do
            create(:event, campaign: campaign,
                           start_date: '07/07/2013', end_date: '07/07/2013')
            create(:event, campaign: campaign,
                           start_date: '07/21/2013', end_date: '07/21/2013')
            Sunspot.commit

            visit events_path

            expect(page).to have_content('1 event found for: Active Today To The Future')
            expect(page).to have_selector('#events-list .resource-item', count: 1)

            add_filter 'CAMPAIGNS', 'Campaign FY2012'
            expect(page).to have_content('1 event found for: Active Today To The Future Campaign FY2012')  # The list shouldn't be filtered by date
            expect(page).to have_selector('#events-list .resource-item', count: 1)
          end
        end

        scenario 'reset filter set the filter options to its initial state' do
          Timecop.travel(Time.zone.local(2013, 07, 21, 12, 01)) do
            create(:event, campaign: campaign, start_date: '07/11/2013', end_date: '07/11/2013')
            create(:event, campaign: campaign, start_date: '07/21/2013', end_date: '07/21/2013')

            create(:custom_filter,
                   owner: company_user, name: 'My Custom Filter', apply_to: 'events',
                   filters:  'status%5B%5D=Active')

            Sunspot.commit

            visit events_path
            expect(page).to have_content('1 event found for: Active Today To The Future')
            expect(page).to have_selector('#events-list .resource-item', count: 1)

            expect(page).to have_content('1 event found for: Active Today To The Future')

            select_saved_filter 'My Custom Filter'

            expect(page).to have_content('2 events found for: My Custom Filter')

            add_filter 'CAMPAIGNS', 'Campaign FY2012'
            expect(page).to have_content('2 events found for: Campaign FY2012 My Custom Filter')

            within('.filter-box') do
              click_button 'cancel-save-filters'
            end

            expect(page).to have_content('1 event found for: Active Today To The Future')

            within '#collection-list-filters' do
              expect(find_field('user-saved-filter', visible: false).value).to eq('')
            end

            expect(page).to have_selector('#events-list .resource-item', count: 1)
            add_filter 'CAMPAIGNS', 'Campaign FY2012'

            expect(page).to have_content('1 event found for: Active Today To The Future Campaign FY2012')
            expect(page).to have_selector('#events-list .resource-item', count: 1)

            remove_filter 'Today To The Future'
            expect(page).to have_content('2 events found for: Active Campaign FY2012')
            expect(page).to have_selector('#events-list .resource-item', count: 2)

            within('.filter-box') do
              click_button 'cancel-save-filters'
            end
            expect(page).to have_content('1 event found for: Active Today To The Future')
          end
        end

        feature 'with timezone support turned ON' do
          before do
            company.update_column(:timezone_support, true)
            user.reload
          end
          scenario "should display the dates relative to event's timezone" do
            Timecop.travel(Time.zone.local(2013, 07, 21, 12, 01)) do
              # Create a event with the time zone "Central America"
              Time.use_zone('Central America') do
                create(:event, company: company,
                               start_date: '08/21/2013', end_date: '08/21/2013',
                               start_time: '10:00am', end_time: '11:00am')
              end

              # Just to make sure the current user is not in the same timezone
              expect(user.time_zone).to eq('Pacific Time (US & Canada)')

              Sunspot.commit
              visit events_path

              within resource_item 1 do
                expect(page).to have_content('WED Aug 21')
                expect(page).to have_content('10:00 AM - 11:00 AM')
              end
            end
          end
        end

        feature 'filters' do
          it_behaves_like 'a list that allow saving custom filters' do
            before do
              create(:campaign, name: 'Campaign 1', company: company)
              create(:campaign, name: 'Campaign 2', company: company)
              create(:area, name: 'Area 1', company: company)
            end

            let(:list_url) { events_path }

            let(:filters) do
              [{ section: 'CAMPAIGNS', item: 'Campaign 1' },
               { section: 'CAMPAIGNS', item: 'Campaign 2' },
               { section: 'AREAS',     item: 'Area 1' },
               { section: 'ACTIVE STATE', item: 'Inactive' }]
            end
          end

          scenario 'Users must be able to filter on all brands they have permissions to access ' do
            today = Time.zone.local(Time.now.year, Time.now.month, 18, 12, 00)
            tomorrow = today + 1.day
            Timecop.travel(today) do
              ev1 = create(:event,
                           start_date: today.to_s(:slashes), end_date: today.to_s(:slashes),
                           start_time: '10:00am', end_time: '11:00am',
                           campaign: campaign,
                           place: create(:place, name: 'Place 1', city: 'Los Angeles', state: 'CA', country: 'US'))
              ev2 = create(:event,
                           start_date: tomorrow.to_s(:slashes), end_date: tomorrow.to_s(:slashes),
                           start_time: '11:00am',  end_time: '12:00pm',
                           campaign: create(:campaign, name: 'Another Campaign April 03', company: company),
                           place: create(:place, name: 'Place 2', city: 'Austin', state: 'TX', country: 'US'))
              brands = [
                create(:brand, name: 'Cacique', company: company),
                create(:brand, name: 'Smirnoff', company: company)
              ]
              create(:brand, name: 'Centenario')  # Brand not added to the user/campaing
              ev1.campaign.brands << brands.first
              ev2.campaign.brands << brands.last
              company_user.brands << brands
              Sunspot.commit
              visit events_path

              expect(page).to have_filter_section(title: 'BRANDS', options: %w(Cacique Smirnoff))

              within events_list do
                expect(page).to have_content('Campaign FY2012')
                expect(page).to have_content('Another Campaign April 03')
              end

              add_filter 'BRANDS', 'Cacique'

              within events_list do
                expect(page).to have_content('Campaign FY2012')
                expect(page).to have_no_content('Another Campaign April 03')
              end
              remove_filter 'Cacique'
              add_filter 'BRANDS', 'Smirnoff'

              within events_list do
                expect(page).to have_no_content('Campaign FY2012')
                expect(page).to have_content('Another Campaign April 03')
              end
            end
          end

          scenario 'Users must be able to filter on all areas they have permissions to access ' do
            areas = [
              create(:area, name: 'Gran Area Metropolitana',
                            description: 'Ciudades principales de Costa Rica', company: company),
              create(:area, name: 'Zona Norte',
                            description: 'Ciudades del Norte de Costa Rica', company: company),
              create(:area, name: 'Inactive Area', active: false,
                            description: 'This should not appear', company: company)
            ]
            areas.each do |area|
              company_user.areas << area
            end
            Sunspot.commit

            visit events_path

            expect(page).to have_filter_section(title: 'AREAS',
                                                options: ['Gran Area Metropolitana', 'Zona Norte'])
          end
        end
      end
    end

    feature 'custom filters' do
      let(:campaign1) { create(:campaign, name: 'Campaign 1', company: company) }
      let(:campaign2) { create(:campaign, name: 'Campaign 2', company: company) }
      let(:event1) { create(:submitted_event, campaign: campaign1) }
      let(:event2) { create(:late_event, campaign: campaign2) }
      let(:user1) { create(:company_user, user: create(:user, first_name: 'Roberto', last_name: 'Gomez'), company: company) }
      let(:user2) { create(:company_user, user: create(:user, first_name: 'Mario', last_name: 'Moreno'), company: company) }


      scenario 'allows to apply custom filters' do
        event1.users << user1
        event2.users << user2
        Sunspot.commit

        create(:custom_filter,
               owner: company_user, name: 'Custom Filter 1', apply_to: 'events',
               filters: 'campaign%5B%5D=' + campaign1.to_param + '&user%5B%5D=' + user1.to_param +
                        '&event_status%5B%5D=Submitted&status%5B%5D=Active')
        create(:custom_filter,
               owner: company_user, name: 'Custom Filter 2', apply_to: 'events',
               filters: 'campaign%5B%5D=' + campaign2.to_param + '&user%5B%5D=' + user2.to_param +
                        '&event_status%5B%5D=Late&status%5B%5D=Active')

        visit events_path

        within events_list do
          expect(page).to have_content('Campaign 1')
          expect(page).to_not have_content('Campaign 2')
        end

        # Using Custom Filter 1
        select_saved_filter 'Custom Filter 1'

        within events_list do
          expect(page).to have_content('Campaign 1')
        end

        within '.form-facet-filters' do
          expect(find_field('Campaign 2')['checked']).to be_falsey
          expect(find_field('Mario Moreno')['checked']).to be_falsey
          expect(find_field('Late')['checked']).to be_falsey

          expect(collection_description).to have_filter_tag('Custom Filter 1')
          expect(page).not_to have_field('Custom Filter 1')

          expect(find_field('Inactive')['checked']).to be_falsey
        end

        # Using Custom Filter 2 should update results and checked/unchecked checkboxes
        select_saved_filter 'Custom Filter 2'

        # Should uncheck Custom Filter 1's params
        expect(collection_description).not_to have_filter_tag('Submitted')
        expect(collection_description).not_to have_filter_tag('Campaign 1')
        expect(collection_description).not_to have_filter_tag('Roberto Gomez')

        # Should have the Custom Filter 2's
        expect(collection_description).to have_filter_tag('Custom Filter 2')

        within events_list do
          expect(page).not_to have_content('Campaign 1')
          expect(page).to have_content('Campaign 2')
        end

        within '.form-facet-filters' do
          expect(page).to have_field('Campaign 1')
          expect(page).to have_field('Roberto Gomez')
          expect(page).to have_field('Submitted')
          expect(page).to have_field('Inactive')
          expect(page).not_to have_field('Custom Filter 2')
        end
      end

      scenario 'when there are 3 lines filter tags show more is displayed' do
        (100..200).each do |user_id|
          create(:company_user, user: create(:user, first_name: 'Roberto', last_name: 'Gomez' + user_id.to_s), company: company)
        end

        event1.users << user1
        event2.users << user2
        user_params = []
        (100..200).each  do |user_id|
          user_params << '&user%5B%5d=' + user_id.to_s
        end
        Sunspot.commit

        create(:custom_filter,
               owner: company_user, name: 'Custom Filter 1', apply_to: 'events',
               filters: 'campaign%5B%5D=' + campaign1.to_param + '&user%5B%5D=' + user1.to_param + user_params.join('') +
                   '&event_status%5B%5D=Submitted&status%5B%5D=Active')
        create(:custom_filter,
               owner: company_user, name: 'Custom Filter 2', apply_to: 'events',
               filters: 'campaign%5B%5D=' + campaign2.to_param + '&user%5B%5D=' + user2.to_param +
                   '&event_status%5B%5D=Late&status%5B%5D=Active')

        visit events_path

        # Using Custom Filter 1
        select_saved_filter 'Custom Filter 1'
        wait_for_ajax(50)
        expand_filter 'Custom Filter 1'
        wait_for_ajax(50)
        expect(page).to have_content('Show more...')
        click_js_link 'Show more...'
        expect(page).to have_content('Show less...')
        within events_list do
          expect(page).to have_content('Campaign 1')
        end
      end
    end

    feature 'create a event' do
      scenario 'allows to create a new event' do
        create(:company_user,
               company: company,
               user: create(:user, first_name: 'Other', last_name: 'User'))
        create(:campaign, company: company, name: 'ABSOLUT Vodka')
        visit events_path

        click_button 'New Event'
        wait_for_ajax(100)
        within visible_modal do
          expect(page).to have_content(company_user.full_name)
          select_from_chosen('ABSOLUT Vodka', from: 'Campaign')
          select_from_chosen('Other User', from: 'Event staff')
          fill_in 'Description', with: 'some event description'
          click_button 'Create'
        end
        ensure_modal_was_closed
        expect(page).to have_content('ABSOLUT Vodka')
        expect(page).to have_content('some event description')
        within '#event-team-members' do
          expect(page).to have_content('Other User')
        end
      end

      scenario 'end date are updated after user changes the start date' do
        Timecop.travel(Time.zone.local(2013, 07, 30, 12, 00)) do
          create(:campaign, company: company)
          visit events_path

          click_button 'New Event'

          within visible_modal do
            # Test both dates are the same
            expect(page).to have_field('Start', with: '07/30/2013')
            expect(page).to have_field('End', with: '07/30/2013')

            # Change the start date and make sure the end date is changed automatically
            find_field('event_start_date').click
            find_field('event_start_date').set '07/29/2013'
            find_field('event_end_date').click
            expect(find_field('event_end_date').value).to eql '07/29/2013'

            # Now, change the end data to make them different and test that the difference
            # is kept after changing start date
            find_field('event_end_date').set '07/31/2013'
            find_field('event_start_date').click
            find_field('event_start_date').set '07/20/2013'
            find_field('event_end_date').click
            expect(find_field('event_end_date').value).to eql '07/22/2013'

            # Change the start time and make sure the end date is changed automatically
            # to one hour later
            find_field('event[start_time]').click
            find_field('event[start_time]').set '08:00am'
            find_field('event[end_time]').click
            expect(page).to have_field('event[end_time]', with: '9:00am')

            find_field('event[start_time]').click
            find_field('event[start_time]').set '4:00pm'
            find_field('event[end_time]').click
            expect(page).to have_field('event[end_time]', with: '5:00pm')
          end
        end
      end

      scenario 'end date are updated next day' do
        Timecop.travel(Time.zone.local(2013, 07, 30, 12, 00)) do
          create(:campaign, company: company)
          visit events_path

          click_button 'New Event'

          within visible_modal do
            # Test both dates are the same
            expect(find_field('event_start_date').value).to eql '07/30/2013'
            expect(find_field('event_end_date').value).to eql '07/30/2013'

            # Change the start time and make sure the end date is changed automatically
            # to one day later
            find_field('event_start_time').click
            find_field('event_start_time').set '11:00pm'
            find_field('event_end_time').click
            expect(find_field('event_end_date').value).to eql '07/31/2013'

            find_field('event_start_date').click
            find_field('event_start_date').set '07/31/2013'
            find_field('event_end_time').click
            find_field('event_end_time').set '2:00pm'
            find_field('event_end_time').click
            expect(find_field('event_end_date').value).to eql '08/01/2013'
          end
        end
      end
    end

    feature 'edit a event' do
      scenario 'allows to edit a event' do
        create(:campaign, company: company, name: 'ABSOLUT Vodka FY2013')
        create(:event,
               start_date: 3.days.from_now.to_s(:slashes),
               end_date: 3.days.from_now.to_s(:slashes),
               start_time: '8:00 PM', end_time: '11:00 PM',
               campaign: create(:campaign, name: 'ABSOLUT Vodka FY2012', company: company))
        Sunspot.commit

        visit events_path

        within resource_item do
          click_js_button 'Edit Event'
        end

        within visible_modal do
          expect(find_field('event_start_date').value).to eq(3.days.from_now.to_s(:slashes))
          expect(find_field('event_end_date').value).to eq(3.days.from_now.to_s(:slashes))
          expect(find_field('event_start_time').value).to eq('8:00pm')
          expect(find_field('event_end_time').value).to eq('11:00pm')

          select_from_chosen('ABSOLUT Vodka FY2013', from: 'Campaign')
          click_js_button 'Save'
        end
        ensure_modal_was_closed
        expect(page).to have_content('ABSOLUT Vodka FY2013')
      end

      scenario 'allows to add or delete users or teams.' do
        create(:campaign, company: company, name: 'ABSOLUT Vodka FY2013')
        create(:company_user,
               company: company,
               user: create(:user, first_name: 'Other', last_name: 'User'))
        create(:company_user,
               company: company,
               user: create(:user, first_name: 'Sara', last_name: 'Smith'))
        team = create(:team, name: 'Good Team', description: 'Good Team', active: true, company_id: company.id)
        user1 = create(:company_user, user: create(:user, first_name: 'Roberto', last_name: 'Gomez'), company: company)
        user2 = create(:company_user, user: create(:user, first_name: 'Mario', last_name: 'Moreno'), company: company)
        team.users << [user1, user2]

        event = create(:event,
                       start_date: 3.days.from_now.to_s(:slashes),
                       end_date: 3.days.from_now.to_s(:slashes),
                       start_time: '8:00 PM', end_time: '11:00 PM',
                       campaign: create(:campaign, name: 'ABSOLUT Vodka FY2012', company: company))
        Sunspot.commit

        visit events_path

        within resource_item do
          click_js_button 'Edit Event'
        end

        within visible_modal do
          select_from_chosen('Other User', from: 'Event staff')
          select_from_chosen('Good Team', from: 'Event staff')
          select_from_chosen('Sara Smith', from: 'Event staff')
          click_js_button 'Save'
        end
        ensure_modal_was_closed

        visit event_path(event)

        within '#event-team-members' do
          expect(page).to have_content('Other User')
          expect(page).to have_content('Good Team')
          expect(page).to have_content('Sara Smith')
        end

        click_js_button 'Edit Event'

        within visible_modal do
          expect(page).to have_selector('.chosen_team', count: 1)
          find('li.chosen_team .search-choice-close').click
          expect(page).to have_selector('.chosen_team', count: 0)
          click_js_button 'Save'
        end
        ensure_modal_was_closed
        visit event_path(event)

        within '#event-team-members' do
          expect(page).to have_content('Other User')
          expect(page).to_not have_content('Good Team')
          expect(page).to have_content('Sara Smith')
        end
      end

      feature 'with timezone support turned ON' do
        before do
          company.update_column(:timezone_support, true)
          user.reload
        end
        scenario "should display the dates relative to event's timezone" do
          date = 3.days.from_now.to_s(:slashes)
          Time.use_zone('America/Guatemala') do
            create(:event,
                   start_date: date, end_date: date,
                   start_time: '8:00 PM', end_time: '11:00 PM',
                   campaign: create(:campaign, name: 'ABSOLUT Vodka FY2012', company: company))
          end
          Sunspot.commit

          Time.use_zone('America/New_York') do
            visit events_path

            within resource_item do
              click_js_button 'Edit Event'
            end

            within visible_modal do
              expect(find_field('event_start_date').value).to eq(date)
              expect(find_field('event_end_date').value).to eq(date)
              expect(find_field('event_start_time').value).to eq('8:00pm')
              expect(find_field('event_end_time').value).to eq('11:00pm')

              fill_in('event_start_time', with: '10:00pm')
              fill_in('event_end_time', with: '11:00pm')

              click_button 'Save'
            end
            ensure_modal_was_closed
            expect(page).to have_content('10:00 PM - 11:00 PM')
          end

          # Check that the event's time is displayed with the same time in a different tiem zone
          Time.use_zone('America/Los_Angeles') do
            visit events_path
            within events_list do
              expect(page).to have_content('10:00 PM - 11:00 PM')
            end
          end
        end
      end
    end

    feature '/events/:event_id', js: true do
      scenario 'a user can play and dismiss the video tutorial' do
        event = create(:event,
                       start_date: '08/28/2013', end_date: '08/28/2013',
                       start_time: '8:00 PM', end_time: '11:00 PM',
                       campaign: campaign)
        visit event_path(event)

        feature_name = 'GETTING STARTED: EVENT DETAILS'

        expect(page).to have_selector('h5', text: feature_name)
        expect(page).to have_content('The Event Details page manages the entire event lifecycle')
        click_link 'Play Video'

        within visible_modal do
          click_js_link 'Close'
        end
        ensure_modal_was_closed

        within('.new-feature') do
          click_js_link 'Dismiss'
        end
        wait_for_ajax

        visit event_path(event)
        expect(page).to have_no_selector('h5', text: feature_name)
      end

      scenario 'GET show should display the event details page' do
        event = create(:event, campaign: campaign,
                               start_date: '08/28/2013', end_date: '08/28/2013',
                               start_time: '8:00 PM', end_time: '11:00 PM')
        visit event_path(event)
        expect(page).to have_selector('h2', text: 'Campaign FY2012')
        within('.calendar-data') do
          expect(page).to have_content('WED Aug 28, 2013 from 8:00 PM to 11:00 PM')
        end
      end

      feature 'close event details' do
        scenario 'allows to close event details' do
          campaign = create(:campaign, name: 'ABSOLUT Vodka FY2012', company: company)

          field = create(:form_field,
                          name: 'Custom Single Text',
                          type: 'FormField::Text',
                          settings: { 'range_format' => 'characters', 'range_min' => '5', 'range_max' => '20' },
                          fieldable: campaign,
                          required: false)
          event = create(:event,
                          start_date: Date.today.to_s(:slashes), end_date: Date.today.to_s(:slashes),
                          campaign: campaign, place: place)

          Sunspot.commit
          visit events_path

          within resource_item(1) do
            click_js_link 'Event Details'
          end

          fill_in 'Custom Single Text', with: 'Testing Single'

          click_js_button 'Save'
          wait_for_ajax

          click_js_button 'Submit'

          wait_for_ajax

          click_js_link('Close Event')

          expect(page).to have_content('Today To The Future')

          within resource_item(1) do
            click_js_link 'Event Details'
          end

          click_link('Edit event data')

          wait_for_ajax

          click_js_button 'Save'
          wait_for_ajax

          click_js_button 'Approve'

          click_js_link('Close Event')

          expect(page).to have_content('Today To The Future')
        end
      end

      feature 'with timezone suport turned ON' do
        before do
          company.update_column(:timezone_support, true)
          user.reload
        end

        scenario "should display the dates relative to event's timezone" do
          # Create a event with the time zone "Central America"
          event = Time.use_zone('Central America') do
            create(:event, campaign: campaign,
                           start_date: '08/21/2013', end_date: '08/21/2013',
                           start_time: '10:00am', end_time: '11:00am')
          end

          # Just to make sure the current user is not in the same timezone
          expect(user.time_zone).to eq('Pacific Time (US & Canada)')

          visit event_path(event)

          within('.calendar-data') do
            expect(page).to have_content('WED Aug 21, 2013 from 10:00 AM to 11:00 AM')
          end
        end
      end

      scenario 'allows to remove users and teams from the event staff', js: true do
        user = create(:user, first_name: 'Pablo', last_name: 'Baltodano', company_id: company.id)
        team = create(:team, name: 'Team 1', company: company)
        create(:membership, company_user: user.company_users.first, memberable: event)
        create(:teaming, team: team, teamable: event)
        Sunspot.commit

        visit event_path(event)

        # Test the user and the team are present in the list of the event staff, remove them
        within staff_list do
          expect(page).to have_content('Pablo Baltodano')
          expect(page).to have_content('Team 1')
          click_js_link 'Remove User'
          click_js_link 'Remove Team'
          expect(page).to_not have_content('Pablo Baltodano')
          expect(page).to_not have_content('Team 1')
        end

        # Refresh the page and make sure the user and the team are not there
        visit event_path(event)

        expect(page).to_not have_content('Pablo Baltodano')
        expect(page).to_not have_content('Team 1')
      end

      scenario 'allows to add a user as contact to the event', js: true do
        create(:user, first_name: 'Pablo', last_name: 'Baltodano',
                      email: 'palinair@gmail.com', company_id: company.id,
                      role_id: company_user.role_id)
        # Adding this to avoid the "event successfully completed" message
        event.campaign.update_attribute(:modules, 'comments' => { 'name' => 'comments', 'field_type' => 'module',
                                                                  'settings' => { 'range_min' => '2', 'range_max' => '3' } })
        Sunspot.commit

        visit event_path(event)

        click_js_button 'Add Contacts'
        within visible_modal do
          fill_in 'contact-search-box', with: 'Pab'
          expect(page).to have_content('Pablo Baltodano')
          within resource_item do
            click_js_link('Add')
          end

          expect(page).to have_no_content('Pablo Baltodano')
        end
        close_modal
        expect(page).to have_content('Good work. One contact have been added.')

        # Test the user was added to the list of event members and it can be removed
        within contact_list do
          expect(page).to have_content('Pablo Baltodano')
          click_js_link 'Remove Contact'
          expect(page).to_not have_content('Pablo Baltodano')
        end

        # Refresh the page and make sure the user is not there
        visit event_path(event)

        expect(page).to_not have_content('Pablo Baltodano')
      end

      scenario 'allows to add a contact as contact to the event', js: true do
        create(:contact, first_name: 'Pedro', last_name: 'Urrutia',
                         company_id: company.id)
        create(:contact, first_name: 'Pedro', last_name: 'Guerra',
                         company_id: company.id)
        # Adding this to avoid the "event successfully completed" message
        event.campaign.update_attribute(:modules, 'comments' => { 'name' => 'comments', 'field_type' => 'module',
                                                                  'settings' => { 'range_min' => '2', 'range_max' => '3' } })
        Sunspot.commit

        visit event_path(event)

        click_js_button 'Add Contacts'
        within visible_modal do
          fill_in 'contact-search-box', with: 'Ped'
          expect(page).to have_content('Pedro Guerra')
          expect(page).to have_content 'Pedro Urrutia'
          within resource_item(1) do
            click_js_link 'Add'
          end
          expect(page).to have_no_content('Pedro Guerra')
          within resource_item(1) do
            click_js_link 'Add'
          end

          expect(page).to have_no_content 'Pedro Urrutia'
        end
        close_modal
        expect(page).to have_content('Good work. 2 contacts have been added.')

        # Test the user was added to the list of event members and it can be removed
        within contact_list do
          expect(page).to have_content('Pedro Guerra')
          expect(page).to have_content('Pedro Urrutia')
          within find('.user-tag-option', text: 'Pedro Urrutia') do
            click_js_link 'Remove Contact'
          end
        end
        expect(page).to_not have_content('Pedro Urrutia')

        # Refresh the page and make sure the user is not there
        visit event_path(event)

        expect(page).to_not have_content('Pedro Urrutia')
      end

      scenario 'allows to create a contact', js: true do
        visit event_path(event)

        click_js_button 'Add Contacts'
        visible_modal.click_js_link('Create New Contact')

        within '.contactevent_modal' do
          fill_in 'First name', with: 'Pedro'
          fill_in 'Last name', with: 'Picapiedra'
          fill_in 'Email', with: 'pedro@racadura.com'
          fill_in 'Phone number', with: '+1 505 22343222'
          fill_in 'Address', with: 'ABC 123'
          select_from_chosen('United States of America', from: 'Country')
          select_from_chosen('California', from: 'State')
          fill_in 'City', with: 'Los Angeles'
          fill_in 'Zip code', with: '12345'
          click_js_button 'Save'
        end

        ensure_modal_was_closed

        # Test the contact was added to the list of event members and it can be removed
        within contact_list do
          expect(page).to have_content('Pedro Picapiedra')
        end

        # Test tooltip
        within contact_list do
          find('.has-tooltip').trigger('click')
        end

        within '.tooltip.in' do
          expect(page).to have_content 'Pedro Picapiedra'
          expect(page).to have_link 'pedro@racadura.com'
          expect(page).to have_link '+1 505 22343222'
          expect(page).to have_content 'ABC 123, Los Angeles, CA, United States'
        end

        # Clink in the tooltip and make sure it isn't closed
        find('.tooltip .contact-name').click
        expect(page).to have_selector('.tooltip.in')

        # Click outside the tooltip and make sure it's closed
        find('.details-title').click
        expect(page).to_not have_selector('.tooltip.in')

        # Test removal of the contact
        click_js_link 'Remove Contact'
        expect(page).to_not have_content('Pedro Picapiedra')

        # Refresh the page and make sure the contact is not there
        visit event_path(event)

        expect(page).to_not have_content('Pedro Picapiedra')
      end

      scenario 'allows to create a new task for the event and mark it as completed' do
        event = create(:event, campaign: create(:campaign, company: company))
        juanito = create(:user, company: company, first_name: 'Juanito', last_name: 'Bazooka')
        juanito_user = juanito.company_users.first
        event.users << juanito_user
        event.users << user.company_users.first
        Sunspot.commit

        visit event_path(event)

        click_js_button 'Add Task'
        within('form#new_task') do
          fill_in 'Title', with: 'Pick up the kidz at school'
          fill_in 'Due at', with: '05/16/2013'
          select_from_chosen('Juanito Bazooka', from: 'Assigned To')
          click_js_button 'Submit'
        end

        within resource_item list: '#tasks-list' do
          expect(page).to have_content 'Pick up the kidz at school'
          expect(page).to have_content 'Juanito Bazooka'
          expect(page).to have_content 'THU May 16'
        end

        # Check that the totals where properly updated
        expect(page).to have_text('1INCOMPLETE')
        expect(page).to have_text('0UNASSIGNED')
        expect(page).to have_text('1LATE')

        # Mark the tasks as completed
        within('#event-tasks') do
          checkbox = find('.task-completed-checkbox', visible: :false)
          expect(checkbox['checked']).to be_falsey
          find('.task-completed-checkbox').trigger('click')
        end
        wait_for_ajax

        # Check that the totals where properly updated
        expect(page).to have_text('0INCOMPLETE')
        expect(page).to have_text('0UNASSIGNED')
        expect(page).to have_text('0LATE')

        # refresh the page to make sure the checkbox remains selected
        visit event_path(event)
        expect(find('.task-completed-checkbox', visible: :false)['checked']).to be_truthy
      end

      scenario 'the entered data should be saved automatically when submitting the event recap' do
        kpi = create(:kpi, name: 'Test Field', kpi_type: 'number', capture_mechanism: 'integer')

        campaign.add_kpi kpi

        event = create(:event,
                       start_date: Date.yesterday.to_s(:slashes),
                       end_date: Date.yesterday.to_s(:slashes),
                       campaign: campaign)

        visit event_path(event)

        fill_in 'Test Field', with: '98765'

        click_js_button 'Submit'

        expect(page).to have_content('Great job! Your PER has been submitted for approval.')
        expect(page).to have_content('Test Field 98,765')
      end

      scenario 'cannot submit a event if the per is not valid' do
        kpi = create(:kpi, name: 'Test Field', kpi_type: 'number', capture_mechanism: 'integer')

        field = campaign.add_kpi(kpi)
        field.required = 'true'
        field.save

        event = create(:event,
                       start_date: Date.yesterday.to_s(:slashes),
                       end_date: Date.yesterday.to_s(:slashes),
                       campaign: campaign)

        visit event_path(event)

        expect(page).to_not have_button 'Submit'

        click_js_button 'Save'

        expect(find_field('Test Field')).to have_error('This field is required.')
        fill_in 'Test Field', with: '123'
        click_js_button 'Save'

        expect(page).to have_button 'Submit'
      end

      scenario 'allows to unapprove an approved event' do
        event = create(:approved_event, start_date: Date.yesterday.to_s(:slashes),
                                        end_date: Date.yesterday.to_s(:slashes),
                                        campaign: campaign)

        visit event_path(event)

        expect(page).to have_content('Nice! Your event has been Approved.')

        click_js_button 'Unapprove'

        expect(page).to have_content('Your event have been Unapproved.')
      end

      scenario "succesfully complete and submit an event" do
        event = create(:late_event,
                       campaign: create(:campaign,
                                        company: company, name: 'Campaign FY2012',
                                        brands: [brand],
                                        modules: {
                                          'comments' => {
                                            'name' => 'comments', 'field_type' => 'module',
                                            'settings' => { 'range_min' => '2',
                                                            'range_max' => '3' } } }))

        visit event_path(event)

        expect(page).to_not have_button 'Submit'

        click_js_button 'Add Comment'
        within visible_modal do
          fill_in 'comment[content]', with: 'This is a test comment'
          click_js_button 'Create'
        end
        expect(page).to have_content 'Looks good. Your comment has been saved.'
        expect(page).to have_content 'This is a test comment'

        click_js_button 'Add Comment'
        within visible_modal do
          fill_in 'comment[content]', with: 'This is another test comment'
          click_js_button 'Create'
        end

        expect(page).to have_content 'Great job! You have successfully completed your event. Do not forget to submit for approval.'
        expect(page).to have_content 'This is a test comment'

        click_js_button 'Submit'

        expect(page).to have_content('Great job! Your PER has been submitted for approval.')
      end

      scenario 'allows to add staff to the event' do
        user = create(:company_user, company: company, role: company_user.role,
                                     user: create(:user, first_name: 'Alberto',
                                                         last_name: 'Porras'))
        team = create(:team, name: 'Super Friends', company: company)
        team.users << company_user

        visit event_path(event)

        click_js_button 'Add Staff'
        within visible_modal do
          # Select an user
          within resource_item 1 do
            expect(page).to have_content('Alberto Porras')
            staff_selected?('user', user.id, false)
            select_from_staff('user', user.id)
            staff_selected?('user', user.id, true)
          end

          # Select a team
          within resource_item 2 do
            expect(page).to have_content('Super Friends')
            staff_selected?('team', team.id, false)
            select_from_staff('team', team.id)
            staff_selected?('team', team.id, true)
          end
          click_js_button 'Add 2 Users/Teams'
        end

        within '#event-team-members' do
          expect(page).to have_content('Super Friends')
          expect(page).to have_content('Alberto Porras')
        end

        click_js_button 'Add Staff'
        within visible_modal do
          expect(page).to_not have_content('Super Friends')
          expect(page).to_not have_content('Alberto Porras')
        end
      end

      scenario 'display the correct message when no users/teams match the search string' do
        user = create(:company_user, company: company, role: company_user.role,
                                     user: create(:user, first_name: 'Fulanito',
                                                         last_name: 'DeTal'))
        Sunspot.commit

        visit event_path(event)

        click_js_button 'Add Staff'
        within visible_modal do
          fill_in 'Search for users and teams', with: 'Fulanito'
          expect(page).to have_content('Fulanito DeTal')
          fill_in 'Search for users and teams', with: 'Pepito'
          expect(page).to have_content('No results found for "Pepito"')
        end
      end
    end
  end

  def event_list_item(event)
    ".resource-item#event_#{event.id}"
  end

  def events_list
    '#events-list'
  end

  def contact_list
    '#event-contacts-list'
  end

  def staff_list
    '#event-team-members'
  end

  def tracker_bar
    '.trackers-bar'
  end
end
