require 'rails_helper'

feature 'Results Event Data Page', js: true, search: true  do
  let(:user) { create(:user, company_id: create(:company).id, role_id: create(:role).id) }
  let(:company) { user.companies.first }
  let(:company_user) { user.current_company_user }
  let(:campaign) { create(:campaign, name: 'First Campaign', company: company) }

  before { sign_in user }

  before do
    allow_any_instance_of(Place).to receive(:fetch_place_data).and_return(true)
  end

  feature 'video tutorial', js: true do
    scenario 'a user can play and dismiss the video tutorial' do
      visit results_event_data_path

      feature_name = 'GETTING STARTED: EVENT DATA REPORT'

      expect(page).to have_selector('h5', text: feature_name)
      expect(page).to have_content('The Event Data Report holds all of your post event data')
      click_link 'Play Video'

      within visible_modal do
        click_js_link 'Close'
      end
      ensure_modal_was_closed

      within('.new-feature') do
        click_js_link 'Dismiss'
      end
      wait_for_ajax

      visit results_event_data_path
      expect(page).to have_no_selector('h5', text: feature_name)
    end
  end

  it_behaves_like 'a list that allow saving custom filters' do
    before do
      create(:campaign, name: 'Campaign 1', company: company)
      create(:campaign, name: 'Campaign 2', company: company)
      create(:area, name: 'Area 1', company: company)
    end

    let(:list_url) { results_event_data_path }

    let(:filters) do
      [{ section: 'CAMPAIGNS', item: 'Campaign 1' },
       { section: 'CAMPAIGNS', item: 'Campaign 2' },
       { section: 'AREAS', item: 'Area 1' },
       { section: 'PEOPLE', item: user.full_name },
       { section: 'ACTIVE STATE', item: 'Inactive' }]
    end
  end

  feature 'export as CSV', js: true do
    let(:area1) do
      create(:area, name: 'Upstate Newyork',
             description: 'Ciudades principales de Costa Rica',
             active: true, company: company)
    end
    let(:place) do
      create(:place, name: 'Guillermitos Bar', street_number: '98',
             route: '3rd Ave', city: 'New York', zipcode: '110011')
    end
    let(:month_number) { today.strftime('%m') }
    let(:month_name) { today.strftime('%b') }
    let(:year_number) { today.strftime('%Y').to_i }
    let(:today) { Time.use_zone(user.time_zone) { Time.current } }

    scenario 'should include any custom kpis from all the campaigns' do
      field = create(:form_field_number, name: 'My Numeric Field', fieldable: campaign)
      event = create(:approved_event, company: company, campaign: campaign)
      event.results_for([field]).first.value = '9876'
      event.save

      Sunspot.commit
      visit results_event_data_path

      click_button 'Download'

      wait_for_export_to_complete
    end

    scenario 'should display correct area field for each event' do
      area1.places << place
      campaign.areas << area1
      event = create(:approved_event, start_date: today.to_s(:slashes), end_date: today.to_s(:slashes),
                     start_time: '10:00am', end_time: '11:00am', company: company, campaign: campaign, place: place)
      Sunspot.commit

      visit results_event_data_path

      click_button 'Download'
      wait_for_export_to_complete

      expect(ListExport.last).to have_rows([
        ['CAMPAIGN NAME', 'AREAS', 'TD LINX CODE', 'VENUE NAME', 'ADDRESS', 'COUNTRY', 'CITY', 'STATE', 'ZIP', 'ACTIVE STATE',
         'EVENT STATUS', 'TEAM MEMBERS', 'CONTACTS', 'URL', 'START', 'END', 'SUBMITTED AT', 'APPROVED AT', 'PROMO HOURS', 'SPENT'],
        [campaign.name, 'Upstate Newyork', nil, place.name, 'Guillermitos Bar, 98 3rd Ave, New York, NY, 110011',
         place.country, place.city, place.state, place.zipcode, 'Active', 'Approved', '', '',
         "http://#{Capybara.current_session.server.host}:#{Capybara.current_session.server.port}/events/#{event.id}",
         "#{year_number}-#{month_number}-#{today.strftime('%d')} 10:00", "#{year_number}-#{month_number}-#{today.strftime('%d')} 11:00", nil, nil,
         number_with_precision(event.promo_hours, precision: 2), '0']
      ])
    end
  end
end
