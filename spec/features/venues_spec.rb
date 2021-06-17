require 'rails_helper'

feature 'Venues Section', js: true, search: true do
  let(:company) { create(:company) }
  let(:role) { create(:role, company: company) }
  let(:user) { create(:user, company: company, role_id: role.id) }
  let(:company_user) { user.company_users.first }
  let(:campaign) { create(:campaign, company: company) }
  let(:permissions) { [] }

  before do
    Warden.test_mode!
    add_permissions permissions
    sign_in user
  end

  after do
    Warden.test_reset!
  end

  feature 'List of venues' do
    scenario 'a user can play and dismiss the video tutorial' do
      visit venues_path

      feature_name = 'GETTING STARTED: VENUES'

      expect(page).to have_selector('h5', text: feature_name)
      expect(page).to have_content('Welcome to the Venues module!')
      click_link 'Play Video'

      within visible_modal do
        click_js_link 'Close'
      end
      ensure_modal_was_closed

      within('.new-feature') do
        click_js_link 'Dismiss'
      end
      wait_for_ajax

      visit venues_path
      expect(page).to have_no_selector('h5', text: feature_name)
    end

    scenario 'search for places' do
      visit venues_path
      expect(page).to have_content('You do not have any venues right now.')
      select_places_autocomplete 'San Francisco CA', from: 'Enter a location'
      fill_in 'I am looking for', with: 'Haas-Lilienthal'
      click_js_button 'Search'
      expect(find('#venues-list')).to have_content 'Haas-Lilienthal House'
      find('.resource-item-link', text: 'Haas-Lilienthal House 2007 Franklin Street, San Francisco', exact: true).click

      expect(page).to have_selector('h2', text: 'Haas-Lilienthal House')
      expect(current_path).to eql venue_path(Venue.last)

      find('#resource-close-details').click

      # Returns the user to the results page
      within resource_item do
        expect(page).to have_content('Haas-Lilienthal House')
      end
      expect(find_field('Enter a location').value).to eql 'San Francisco, CA, United States'
      expect(find_field('I am looking for').value).to eql 'Haas-Lilienthal'
    end

    scenario 'GET index should display a list with the venues', :inline_jobs do
      create(:event, campaign: campaign,
                     place: create(:place, name: 'Bar Benito'),
                     results: { impressions: 35, interactions: 65, samples: 15 },
                     expenses: [{ amount: 1000 }])

      create(:event, campaign: campaign,
                     place: create(:place, name: 'Bar Camelas'),
                     results: { impressions: 35, interactions: 65, samples: 15 },
                     expenses: [{ amount: 2000 }])

      Venue.reindex
      Sunspot.commit

      visit venues_path

      # First Row
      within resource_item 1 do
        expect(page).to have_content('Bar Benito')
        expect(page).to have_selector('div.n_spent', text: '$1,000.00')
      end
      # Second Row
      within resource_item 2 do
        expect(page).to have_content('Bar Camelas')
        expect(page).to have_selector('div.n_spent', text: '$2,000.00')
      end
    end
  end

  feature 'export' do
    let(:month_number) { Time.now.strftime('%m') }
    let(:month_name) { Time.now.strftime('%b') }
    let(:year_number) { Time.now.strftime('%Y') }
    let(:today) { Time.zone.local(year_number, month_number, 18, 12, 00) }
    let(:event1) do
      create(:event, campaign: campaign,
                     place: create(:place, name: 'Place 1', td_linx_code: '5155520'),
                     results: { impressions: 35, interactions: 65, samples: 15 },
                     expenses: [{ amount: 1_000 }])
    end
    let(:event2) do
      create(:event, campaign: create(:campaign, name: 'Another Campaign April 03', company: company),
                     place: create(:place, name: 'Place 2',
                        formatted_address: '456 Your Street',
                        city: 'Los Angeles', state: 'CA',
                        zipcode: '67890',
                        td_linx_code: '3929538'),
                     results: { impressions: 45, interactions: 75, samples: 25 },
                     expenses: [{ amount: 2_000 }])
    end

    before do
      inline_jobs { event1 && event2 }
      Venue.reindex
      Sunspot.commit
    end

    scenario 'should be able to export as CSV' do
      visit venues_path

      click_js_link 'Download'
      click_js_link 'Download as CSV'

      wait_for_export_to_complete

      expect(ListExport.last).to have_rows([
        ['VENUE NAME', 'TD LINX CODE', 'ADDRESS', 'CITY', 'STATE', 'SCORE', 'EVENTS COUNT', 'PROMO HOURS COUNT', 'TOTAL $ SPENT'],
        ['Place 1', '5155520', '123 My Street', 'New York City', 'NY', '0', '1', '2.0', '$1,000.00'],
        ['Place 2', '3929538', '456 Your Street', 'Los Angeles', 'CA', '0', '1', '2.0', '$2,000.00']
      ])
    end

    scenario 'should be able to export as PDF', match_requests_on: [:s3_file] do
      visit venues_path

      click_js_link 'Download'
      click_js_link 'Download as PDF'

      wait_for_export_to_complete

      export = ListExport.last
      # Test the generated PDF...
      reader = PDF::Reader.new(open(export.file.url))
      reader.pages.each do |page|
        # PDF to text seems to not always return the same results
        # with white spaces, so, remove them and look for strings
        # without whitespaces
        text = page.text.gsub(/[\s\n]/, '')
        expect(text).to include 'Place1'
        expect(text).to include 'Place2'
        expect(text).to include '11MainSt.,NewYorkCity'
        expect(text).to include '11MainSt.,LosAngeles'
        expect(text).to include '$1,000.00'
        expect(text).to include '$2,000.00'
      end
    end

    scenario 'should not be able to export as PDF for documents with more than 200 pages' do
      allow(Venue).to receive(:do_search).and_return(double(total: 3000))

      visit venues_path

      click_js_link 'Download'
      click_js_link 'Download as PDF'

      within visible_modal do
        expect(page).to have_content('PDF exports are limited to 200 pages. Please narrow your results and try exporting again.')
        click_js_link 'OK'
      end
      ensure_modal_was_closed
    end
  end

  shared_examples_for '/venues/:venue_id' do
    scenario 'an user can play and dismiss the video tutorial' do
      venue = create(:venue, company: company,
                             place: create(:place, is_custom_place: true, reference: nil))

      visit venue_path(venue)

      feature_name = 'GETTING STARTED: VENUE DETAILS'

      expect(page).to have_selector('h5', text: feature_name)
      expect(page).to have_content('You are now viewing the Venue Details page')
      click_link 'Play Video'

      within visible_modal do
        click_js_link 'Close'
      end
      ensure_modal_was_closed

      within('.new-feature') do
        click_js_link 'Dismiss'
      end
      wait_for_ajax

      visit venue_path(venue)
      expect(page).to have_no_selector('h5', text: feature_name)
    end

    scenario 'an user can see activities from allowed campaigns only' do
      venue = create(:venue, company: company, place: create(:place, name: 'Bar Benito'))
      company_user.campaigns << campaign

      without_current_user do
        # Activities from Events
        event = create(:event, campaign: campaign, place: venue.place)
        create(:activity,
               company_user: create(:user, company: company).company_users.first, activitable: event, activity_date: '08/21/2014',
               activity_type: create(:activity_type, name: 'Event ActivityType', company: company, campaign_ids: [campaign.id]))

        another_campaign = create(:campaign, company: company, name: 'Another Campaign')
        event2 = create(:event, campaign: another_campaign, place: venue.place)
        create(:activity,
               company_user: create(:user, company: company).company_users.first, activitable: event2, activity_date: '09/12/2014',
               activity_type: create(:activity_type, name: 'Another Event ActivityType', company: company, campaign_ids: [another_campaign.id]))
      
        # Activities from Venue
        create(:activity,
          company_user: create(:user, company: company).company_users.first, activitable: venue, campaign: campaign, activity_date: '07/11/2014',
          activity_type: create(:activity_type, name: 'Venue ActivityType', company: company, campaign_ids: [campaign.id]))

        create(:activity,
          company_user: create(:user, company: company).company_users.first, activitable: venue, campaign: another_campaign, activity_date: '10/06/2014',
          activity_type: create(:activity_type, name: 'Another Venue ActivityType', company: company, campaign_ids: [another_campaign.id]))
      end

      visit venue_path(venue)

      within '#activities-list' do
        expect(page).to have_content('Event ActivityType')
        expect(page).to have_content('Venue ActivityType')
        expect(page).to_not have_content('Another Event ActivityType')
        expect(page).to_not have_content('Another Venue ActivityType')
      end
    end
  end

  feature 'non admin user', js: true do
    let(:role) { create(:non_admin_role, company: company) }

    it_should_behave_like '/venues/:venue_id' do
      let(:permissions) { [[:show, 'Activity'], [:show, 'Venue']] }
    end
  end
end
