require 'rails_helper'

feature 'Results Activity Data Page', js: true, search: true  do
  let(:user) { create(:user, company_id: create(:company).id, role_id: create(:role).id) }
  let(:company) { user.companies.first }
  let(:company_user) { user.current_company_user }
  let(:campaign) { create(:campaign, company: company) }
  let(:activity_type) { create(:activity_type, name: 'My Activity Type', company: company) }
  let(:inactive_event) { create(:submitted_event, company: company, campaign: campaign, place: create(:place, name: 'The Place'), active: false) }
  let(:venue) { create(:venue, place: create(:place, name: 'My Place'), company: company) }
  let(:venue1) { create(:venue, place: create(:place, name: 'Your Place'), company: company) }

  before { sign_in user }

  feature 'Activity Results', js: true, search: true do
    scenario 'GET index should display a table with the activities' do
      event = create(:approved_event, company: company, campaign: campaign, place: create(:place, name: 'Another Place'))
      event_with_merged_place = create(:approved_event,
                                       company: company, campaign: campaign,
                                       place: create(:place, name: 'Merged Place', merged_with_place_id: venue.place.id))
      another_user = create(:user, company: company, first_name: 'Juanito', last_name: 'Bazooka')
      another_at = create(:activity_type, name: 'Second Activity Type', company: company)
      campaign.activity_types << [activity_type, another_at]

      create(:activity, activity_type: activity_type, activitable: venue, campaign: campaign,
                        company_user: company_user, activity_date: '2013-02-04')
      create(:activity, activity_type: another_at, activitable: venue, campaign: campaign,
                        company_user: another_user.company_users.first, activity_date: '2013-03-16')
      create(:activity, activity_type: activity_type, activitable: event, campaign: campaign,
                        company_user: company_user, activity_date: '2013-03-25')
      create(:activity, activity_type: activity_type, activitable: inactive_event, campaign: campaign,
                        company_user: another_user.company_users.first, activity_date: '2013-03-28')
      create(:activity, activity_type: activity_type, activitable: event_with_merged_place, campaign: campaign,
                        company_user: another_user.company_users.first, activity_date: '2013-04-01')

      create(:custom_filter,
             owner: company_user, name: 'My Venues Filter', apply_to: 'activities',
             filters:  "status%5B%5D=Active&venue%5B%5D=#{venue.id}")

      campaign.activity_types << activity_type
      campaign.activity_types << another_at
      Sunspot.commit

      visit results_activities_path

      within('#activities-list') do
        # First Row
        within resource_item 1 do
          expect(page).to have_content('My Activity Type')
          expect(page).to have_content('MON Feb 4, 2013')
          expect(page).to have_content('Test User')
        end

        # Second Row
        within resource_item 2 do
          expect(page).to have_content('Second Activity Type')
          expect(page).to have_content('SAT Mar 16, 2013')
          expect(page).to have_content('Juanito Bazooka')
        end

        # Third Row
        within resource_item 3 do
          expect(page).to have_content('My Activity Type')
          expect(page).to have_content('MON Mar 25, 2013')
          expect(page).to have_content('Test User')
        end

        # Fourth Row
        within resource_item 4 do
          expect(page).to have_content('My Activity Type')
          expect(page).to have_content('MON Apr 1, 2013')
          expect(page).to have_content('Juanito Bazooka')
        end

        # Activities from inactive events should not be displayed
        expect(page).to_not have_content('THU Mar 28, 2013')
      end

      # Filter by venue should display the results including the activity with the merged place
      select_saved_filter 'My Venues Filter'

      within('#activities-list') do
        # First Row
        within resource_item 1 do
          expect(page).to have_content('My Activity Type')
          expect(page).to have_content('MON Feb 4, 2013')
          expect(page).to have_content('Test User')
        end

        # Second Row
        within resource_item 2 do
          expect(page).to have_content('Second Activity Type')
          expect(page).to have_content('SAT Mar 16, 2013')
          expect(page).to have_content('Juanito Bazooka')
        end

        # Third Row
        within resource_item 3 do
          expect(page).to have_content('My Activity Type')
          expect(page).to have_content('MON Apr 1, 2013')
          expect(page).to have_content('Juanito Bazooka')
        end

        # Activities with different venue/place events should not be displayed
        expect(page).to_not have_content('MON Mar 25, 2013')

        # Activities from inactive events should not be displayed
        expect(page).to_not have_content('THU Mar 28, 2013')
      end
    end
    scenario 'GET index should display a filtered activities  based on venues' do
      event = create(:approved_event, company: company, campaign: campaign, place: venue.place)
      another_user = create(:user, company: company, first_name: 'Juanito', last_name: 'Bazooka')
      another_at = create(:activity_type, name: 'Second Activity Type', company: company)
      campaign.activity_types << [activity_type, another_at]

      create(:activity, activity_type: activity_type, activitable: venue, campaign: campaign,
             company_user: company_user, activity_date: '2013-02-04')
      create(:activity, activity_type: another_at, activitable: venue, campaign: campaign,
             company_user: another_user.company_users.first, activity_date: '2013-03-16')
      create(:activity, activity_type: another_at, activitable: venue1, campaign: campaign,
             company_user: another_user.company_users.first, activity_date: '2013-03-18')
      create(:activity, activity_type: activity_type, activitable: event, campaign: campaign,
             company_user: company_user, activity_date: '2013-03-25')

      create(:activity, activity_type: activity_type, activitable: inactive_event, campaign: campaign,
             company_user: another_user.company_users.first, activity_date: '2013-03-28')

      campaign.activity_types << activity_type
      campaign.activity_types << another_at
      Sunspot.commit

      visit results_activities_path
      add_filter 'VENUES', 'My Place'
      within('#activities-list') do
        # First Row
        within resource_item 1 do
          expect(page).to have_content('My Activity Type')
          expect(page).to have_content('MON Feb 4, 2013')
          expect(page).to have_content('Test User')
          expect(page).to have_content('My Place')
        end

        # Second Row
        within resource_item 2 do
          expect(page).to have_content('Second Activity Type')
          expect(page).to have_content('SAT Mar 16, 2013')
          expect(page).to have_content('Juanito Bazooka')
          expect(page).to have_content('My Place')
        end

        # Second Row
        within resource_item 3 do
          expect(page).to have_content('My Activity Type')
          expect(page).to have_content('MON Mar 25, 2013')
          expect(page).to have_content('Test User')
          expect(page).to have_content('My Place')
        end
        # Activities from other venue should not be displayed
        expect(page).to_not have_content('Your Place')
      end
    end
    it_behaves_like 'a list that allow saving custom filters' do
      before do
        create(:campaign, name: 'First Campaign', company: company)
        create(:campaign, name: 'Second Campaign', company: company)
        create(:company_user, user: create(:user, first_name: 'Roberto', last_name: 'Gomez'),
                              company: company)
      end

      let(:list_url) { results_activities_path }

      let(:filters) do
        [{ section: 'CAMPAIGNS', item: 'First Campaign' },
         { section: 'CAMPAIGNS', item: 'Second Campaign' },
         { section: 'USERS', item: 'Roberto Gomez' }]
      end
    end
  end

  feature 'Activity Results showing inactive results', js: true, search: true do
    scenario 'GET index should display a table with the inactive activities' do
      event = create(:approved_event, company: company, campaign: campaign, place: create(:place, name: 'Another Place'))
      another_user = create(:user, company: company, first_name: 'Juanito', last_name: 'Bazooka')
      another_at = create(:activity_type, name: 'Second Activity Type', company: company)
      campaign.activity_types << [activity_type, another_at]

      create(:activity, activity_type: activity_type, activitable: venue, campaign: campaign,
             company_user: company_user, activity_date: '2013-02-04')
      create(:activity, activity_type: another_at, activitable: venue, campaign: campaign,
             company_user: another_user.company_users.first, activity_date: '2013-03-16')
      create(:activity, activity_type: activity_type, activitable: event, campaign: campaign,
             company_user: company_user, activity_date: '2013-03-25')
      create(:activity, activity_type: activity_type, activitable: inactive_event, campaign: campaign,
             company_user: another_user.company_users.first, activity_date: '2013-03-28')

      campaign.activity_types << activity_type
      campaign.activity_types << another_at
      Sunspot.commit

      visit results_activities_path

      within('#activities-list') do
        # First Row
        within resource_item 1 do
          expect(page).to have_content('My Activity Type')
          expect(page).to have_content('MON Feb 4, 2013')
          expect(page).to have_content('Test User')
        end

        # Second Row
        within resource_item 2 do
          expect(page).to have_content('Second Activity Type')
          expect(page).to have_content('SAT Mar 16, 2013')
          expect(page).to have_content('Juanito Bazooka')
        end

        # Third Row
        within resource_item 3 do
          expect(page).to have_content('My Activity Type')
          expect(page).to have_content('MON Mar 25, 2013')
          expect(page).to have_content('Test User')
        end

        # Activities from inactive events should not be displayed
        expect(page).to_not have_content('THU Mar 28, 2013')
      end
    end

    it_behaves_like 'a list that allow saving custom filters' do
      before do
        create(:campaign, name: 'First Campaign', company: company)
        create(:campaign, name: 'Second Campaign', company: company)
        create(:company_user, user: create(:user, first_name: 'Roberto', last_name: 'Gomez'),
               company: company)
      end

      let(:list_url) { results_activities_path }

      let(:filters) do
        [{ section: 'CAMPAIGNS', item: 'First Campaign' },
         { section: 'CAMPAIGNS', item: 'Second Campaign' },
         { section: 'USERS', item: 'Roberto Gomez' }]
      end
    end
  end

  feature 'export', search: true do
    before do
      event = create(:event, campaign: campaign, place: venue.place)
      another_user = create(:user, company: company, first_name: 'Juanito', last_name: 'Bazooka')
      activity_type2 = create(:activity_type, name: 'Second Activity Type', company: company)
      place1 = create(:place, name: 'Custom Name 1', formatted_address: 'Custom Place 1, Curridabat')
      place2 = create(:place, name: 'Custom Name 2', formatted_address: nil)
      place_field1 = create(:form_field, name: 'Custom Place 1', type: 'FormField::Place', fieldable: activity_type, ordering: 1)
      place_field2 = create(:form_field, name: 'Custom Place 2', type: 'FormField::Place', fieldable: activity_type, ordering: 2)
      checkbox_field1 = create(:form_field_checkbox, name: 'Custom Check Field',
        fieldable: activity_type, options: [
          option11 = create(:form_field_option, name: 'Check1 Opt1'),
          option12 = create(:form_field_option, name: 'Check1 Opt2')])
      # Same name than checkbox_field1 to test order by field id
      checkbox_field2 = create(:form_field_checkbox, name: 'Custom Check Field',
        fieldable: activity_type, options: [
          option21 = create(:form_field_option, name: 'Check2 Opt1'),
          option22 = create(:form_field_option, name: 'Check2 Opt2')])

      campaign.activity_types << activity_type
      campaign.activity_types << activity_type2
      # make sure activities are created before
      activity = create(:activity, activity_type: activity_type, activitable: venue, campaign: campaign,
                                   company_user: company_user, activity_date: '2013-02-04',
                                   created_at: DateTime.parse('2015-07-01 02:11 -07:00'),
                                   updated_at: DateTime.parse('2015-07-03 02:11 -07:00'))
      create(:activity, activity_type: activity_type2, activitable: venue, campaign: campaign,
                        company_user: another_user.company_users.first, activity_date: '2013-03-16',
                        created_at: DateTime.parse('2015-07-01 02:11 -07:00'),
                        updated_at: DateTime.parse('2015-07-03 02:11 -07:00'))
      create(:activity, activity_type: activity_type, activitable: event, campaign: campaign,
                        company_user: another_user.company_users.first, activity_date: '2013-09-04',
                        created_at: DateTime.parse('2015-07-01 02:11 -07:00'),
                        updated_at: DateTime.parse('2015-07-03 02:11 -07:00'))
      create(:activity, activity_type: activity_type, activitable: inactive_event, campaign: campaign,
                        company_user: another_user.company_users.first, activity_date: '2013-03-28',
                        created_at: DateTime.parse('2015-07-01 02:11 -07:00'),
                        updated_at: DateTime.parse('2015-07-03 02:11 -07:00'))

      activity.results_for([place_field1]).first.value = place1.id
      activity.results_for([place_field2]).first.value = place2.id
      activity.results_for([checkbox_field1]).first.value = { option11.id.to_s => 1, option12.id.to_s => 1 }
      activity.results_for([checkbox_field2]).first.value = { option21.id.to_s => 1, option22.id.to_s => 1 }
      activity.save

      Sunspot.commit
    end

    scenario 'should be able to export as CSV' do
      visit results_activities_path

      click_js_link 'Download'
      click_js_link 'Download as CSV'

      wait_for_export_to_complete

      expect(ListExport.last).to have_rows([
        ['CAMPAIGN NAME', 'USER', 'DATE', 'ACTIVITY TYPE', 'AREAS', 'TD LINX CODE', 'VENUE NAME', 'ADDRESS',
         'CITY', 'STATE', 'ZIP', 'COUNTRY', 'ACTIVE STATE', 'CREATED AT', 'CREATED BY', 'LAST MODIFIED', 'MODIFIED BY',
         'CUSTOM CHECK FIELD: CHECK1 OPT1', 'CUSTOM CHECK FIELD: CHECK1 OPT2', 'CUSTOM CHECK FIELD: CHECK2 OPT1',
         'CUSTOM CHECK FIELD: CHECK2 OPT2', 'CUSTOM PLACE 1', 'CUSTOM PLACE 2'],
        [campaign.name, 'Test User', '2013-02-04', 'My Activity Type', '', nil, 'My Place',
         'My Place, 11 Main St., New York City, NY, 12345', 'New York City', 'NY', '12345', 'US', 'Active',
         '2015-07-01 02:11', 'Test User', '2015-07-03 02:11', 'Test User', 'Yes', 'Yes', 'Yes', 'Yes',
         'Custom Name 1, 11, Main St., New York City, NY, United States', 'Custom Name 2, 11, Main St., New York City, NY, United States'],
        [campaign.name, 'Juanito Bazooka', '2013-03-16', 'Second Activity Type', '', nil,
         'My Place', 'My Place, 11 Main St., New York City, NY, 12345', 'New York City', 'NY', '12345', 'US', 'Active',
         '2015-07-01 02:11', 'Test User', '2015-07-03 02:11', 'Test User', nil, nil, nil, nil, nil, nil],
        [campaign.name, 'Juanito Bazooka', '2013-09-04', 'My Activity Type', '', nil,
         'My Place', 'My Place, 11 Main St., New York City, NY, 12345', 'New York City', 'NY', '12345', 'US', 'Active',
         '2015-07-01 02:11', 'Test User', '2015-07-03 02:11', 'Test User', nil, nil, nil, nil, nil, nil]
      ])

      expect(ListExport.last).to_not have_rows([
        [campaign.name, 'Juanito Bazooka', '2013-03-28', 'My Activity Type', '', nil, 'The Place',
         'The Place, 11 Main St., New York City, NY, 12345', 'New York City', 'NY', '12345', 'US', 'Active',
         '2015-07-01 02:11', 'Test User', '2015-07-03 02:11', 'Test User', nil, nil, nil, nil, nil, nil]
      ])
    end

    scenario 'should be able to export as PDF' do
      visit results_activities_path

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
        expect(text).to include 'MyActivityType'
        expect(text).to include 'MONFeb4,2013'
        expect(text).to include 'TestUser'
        expect(text).to include 'SecondActivityType'
        expect(text).to include 'SATMar16,2013'
        expect(text).to include 'JuanitoBazooka'
        expect(text).to include 'WEDSep4,2013'
        expect(text).to_not include 'THUMar28,2013'
      end
    end
  end
end
