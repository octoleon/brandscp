require 'rails_helper'

feature 'Dashboard', search: true, js: true do
  let(:company) { create(:company) }
  let(:campaign) { create(:campaign, company: company) }
  let(:user) { create(:user, company: company, role_id: role.id) }
  let(:company_user) { user.company_users.first }
  let(:place) { create(:place, name: 'A Nice Place', country: 'CR', city: 'Curridabat', state: 'San Jose') }
  let(:permissions) { [] }

  before do
    Warden.test_mode!
    add_permissions permissions
    sign_in user
    Company.current = company
  end

  after do
    Warden.test_reset!
  end

  shared_examples_for 'a user that can view the recent comments module' do
    scenario 'should display only 9 comments' do
      create_list(:comment, 15, commentable: create(:event,
                                                    campaign: campaign,
                                                    company: company, place: place))

      visit root_path
      page.execute_script 'window.scrollBy(0,10000)' # Scrolls down to the bottom of the page

      within recent_comments_module do
        expect(page).to have_selector('ul#comments-list-container li', count: 9)
      end
    end
  end

  shared_examples_for 'a user that can view the recent photos module' do
    scenario 'should display latest photos module' do
      create_list(:photo, 15, attachable: create(:event,
                                                 campaign: campaign,
                                                 company: company, place: place))

      Sunspot.commit

      visit root_path
      page.execute_script 'window.scrollBy(0,10000);' # Scrolls down to the bottom of the page

      within recent_photos_module do
        expect(page).to have_selector('ul#photos-thumbs li', count: 12)
      end
    end
  end

  shared_examples_for 'a user that can view the upcoming events module' do
    let(:campaign1) do
      create(:campaign, company: company,
                        name: 'Jameson + Kahlua Rum Campaign',
                        brands_list: 'Jameson,Kahlua Rum,Guaro Cacique,Ron Centenario,Ron Abuelo,Absolut Vodka')
    end

    let(:campaign2) do
      create(:campaign, company: company,
                        name: 'Mama Walker\'s + Martel Campaign',
                        brands_list: 'Mama Walker\'s,Martel')
    end

    let(:campaign3) do
      create(:campaign, company: company,
                        name: 'Paddy Irish Whiskey Campaign',
                        brands_list: 'Paddy Irish Whiskey')
    end

    let(:events) do
      [
        create(:event, campaign: campaign1, place: place, start_date: '01/14/2014', end_date: '01/15/2014'),
        create(:event, campaign: campaign2, place: place, start_date: '01/27/2014', end_date: '01/27/2014'),
        create(:event, campaign: campaign3, place: place, start_date: '01/14/2014', end_date: '01/14/2014')]
    end

    feature 'video tutorial' do
      scenario 'a user can play and dismiss the video tutorial' do
        visit root_path

        feature_name = 'GETTING STARTED: DASHBOARD'

        expect(page).to have_selector('h5', text: feature_name)
        expect(page).to have_content('On this page you will find a quick overview')
        click_link 'Play Video'

        within visible_modal do
          click_js_link 'Close'
        end
        ensure_modal_was_closed

        within('.new-feature') do
          click_js_link 'Dismiss'
        end
        wait_for_ajax

        visit root_path
        expect(page).to have_no_selector('h5', text: feature_name)
      end
    end

    feature 'Events List View' do
      before { events  } # Create the events
      before { Sunspot.commit }
      scenario 'should display a list of upcoming events' do
        Timecop.travel(Time.zone.local(2014, 01, 14, 12, 00)) do
          visit root_path
          within upcoming_events_module do
            expect(all('.resource-item').count).to eql 3
            expect(page).to have_content('Jameson + Kahlua Rum Campaign')
            expect(page).to have_content('Mama Walker\'s + Martel Campaign')
            expect(page).to have_content('Paddy Irish Whiskey Campaign')
          end
        end
      end
    end

    feature 'Events Calendar View' do
      before { events  } # Create the events
      before { Sunspot.commit }

      scenario "should start with today's day and show 2 weeks" do
        # Today is Tuesday, Jan 11
        Timecop.travel(Time.zone.local(2014, 01, 14, 12, 00)) do
          visit root_path

          within upcoming_events_module do
            click_link 'Calendar View'

            # Check that the calendar was correctly created starting with current week day
            expect(find('.calendar-header th:nth-child(1)')).to have_content('TUE')
            expect(find('.calendar-header th:nth-child(2)')).to have_content('WED')
            expect(find('.calendar-header th:nth-child(3)')).to have_content('THU')
            expect(find('.calendar-header th:nth-child(4)')).to have_content('FRI')
            expect(find('.calendar-header th:nth-child(5)')).to have_content('SAT')
            expect(find('.calendar-header th:nth-child(6)')).to have_content('SUN')
            expect(find('.calendar-header th:nth-child(7)')).to have_content('MON')

            expect(find('.calendar-table tbody tr:nth-child(1) td:nth-child(1)')).to have_content('14')
            expect(find('.calendar-table tbody tr:nth-child(2) td:nth-child(7)')).to have_content('27')

            # Check that the brands appears on the correct cells
            # 01/14/2014
            expect(find('.calendar-table tbody tr:nth-child(1) td:nth-child(1)')).to have_content('Jameson')
            expect(find('.calendar-table tbody tr:nth-child(1) td:nth-child(1)')).to have_content('Kahlua Rum')
            expect(find('.calendar-table tbody tr:nth-child(1) td:nth-child(1)')).to have_content('Paddy Irish Whiskey')

            # 01/15/2014
            expect(find('.calendar-table tbody tr:nth-child(1) td:nth-child(2)')).to have_content('Jameson')
            expect(find('.calendar-table tbody tr:nth-child(1) td:nth-child(2)')).to have_content('Kahlua Rum')
            expect(find('.calendar-table tbody tr:nth-child(1) td:nth-child(2)')).to have_no_content('Paddy Irish Whiskey')

            # 01/27/2014
            expect(find('.calendar-table tbody tr:nth-child(2) td:nth-child(7)')).to have_content('Mama Walker\'s')
            expect(find('.calendar-table tbody tr:nth-child(2) td:nth-child(7)')).to have_content('Martel')
          end
        end
      end

      scenario 'clicking on the day should take the user to the event list for that day' do
        Timecop.travel(Time.zone.local(2014, 01, 14, 12, 00)) do
          visit root_path

          within upcoming_events_module do
            click_link 'Calendar View'
            click_link '14'
          end

          expect(current_path).to eql events_path

          # The 14 should appear selected in the calendar
          expect(page).to have_selector('a.datepick-event.datepick-selected', text: 14)

          within('#events-list') do
            expect(all('.resource-item').count).to eql 2
            expect(page).to have_content('Jameson + Kahlua Rum Campaign')
            expect(page).to have_content('Paddy Irish Whiskey Campaign')
          end
        end
      end

      scenario 'clicking on the brand should take the user to the event list filtered for that date and brand' do
        Timecop.travel(Time.zone.local(2014, 01, 14, 12, 00)) do
          visit root_path

          within upcoming_events_module do
            expect(page).to have_content('Paddy Irish Whiskey Cam')
            click_link 'Calendar View'
            expect(page).not_to have_content('Paddy Irish Whiskey Cam')
            click_link 'Paddy Irish Whiskey'
          end

          # The 14 should appear selected in the calendar
          expect(page).to have_selector('a.datepick-event.datepick-selected', text: 14)

          expect(current_path).to eql events_path

          within('#events-list') do
            expect(all('.resource-item').count).to be 1
            expect(page).to have_content('Paddy Irish Whiskey Campaign')
          end
        end
      end

      scenario "a day with more than 6 brands should display a 'more' link" do
        Timecop.travel(Time.zone.local(2014, 01, 14, 12, 00)) do
          create(:event,
                 campaign: campaign1, place: place,
                 start_date: '01/14/2014', end_date: '01/14/2014')
          Sunspot.commit

          visit root_path

          within upcoming_events_module do
            click_link 'Calendar View'

            within '.calendar-table tbody tr:nth-child(1) td:nth-child(1)' do
              expect(page).to have_link('+1 More')
              click_link '+1 More'
              expect(page).to have_content('Tue Jan 14')
              expect(page).to have_no_content('+1 More')
            end
          end
        end
      end
    end
  end
  feature 'Admin User' do
    let(:role) { create(:role, company: company) }

    # it_behaves_like 'a user that can view the upcoming events module'

    it_behaves_like 'a user that can view the recent comments module'
    it_behaves_like 'a user that can view the recent photos module'
  end
  feature 'Non Admin User', js: true, search: true do
    let(:role) { create(:non_admin_role, company: company) }

    it_should_behave_like 'a user that can view the upcoming events module' do
      before { company_user.campaigns << [campaign, campaign1, campaign2, campaign3] }
      before { company_user.places << create(:place, city: nil, state: 'San Jose', country: 'CR', types: ['locality']) }
      let(:permissions) { [[:upcomings_events_module, 'Symbol', 'dashboard'], [:view_calendar, 'Event'],  [:view_list, 'Event']] }
    end

    it_should_behave_like 'a user that can view the recent comments module' do
      before { company_user.campaigns << [campaign] }
      before { company_user.places << place }
      let(:permissions) { [[:recent_comments_module, 'Symbol', 'dashboard'], [:view_list, 'Event']] }
    end

    it_should_behave_like 'a user that can view the recent photos module' do
      before { company_user.campaigns << [campaign] }
      before { company_user.places << place }
      let(:permissions) { [[:recent_photos_module, 'Symbol', 'dashboard'], [:index_photos, 'Event']] }
    end
  end
  def upcoming_events_module
    find('div#upcomming-events-module')
  end

  def recent_comments_module
    find('div#recent-comments-module')
  end

  def recent_photos_module
    find('div#recent-photos-module')
  end

end
