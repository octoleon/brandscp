require 'rails_helper'

feature 'Activities management' do
  let(:company) { create(:company) }
  let(:campaign) { create(:campaign, company: company) }
  let(:user) { create(:user, company: company, role_id: role.id) }
  let(:company_user) { user.company_users.first }
  let(:place) { create(:place, name: 'A Nice Place', country: 'CR', city: 'Curridabat', state: 'San José', is_custom_place: true, reference: nil) }
  let(:permissions) { [] }
  let(:event) { create(:late_event, campaign: campaign, company: company, place: place) }

  before do
    Warden.test_mode!
    add_permissions permissions
    sign_in user
  end
  after do
    AttachedAsset.destroy_all
    Warden.test_reset!
  end

  shared_examples_for 'a user that view the activiy details' do
    let(:activity) do
      create(:activity,
             company_user: company_user, activitable: event, activity_date: '08/21/2014',
             activity_type: create(:activity_type, name: 'Test ActivityType', company: company, campaign_ids: [campaign.id]))
    end

    scenario 'can see all the activity info', js: true do
      visit activity_path(activity)
      expect(page).to have_selector('h2', text: 'Test ActivityType')
      expect(current_path).to eql activity_path(activity)
    end

    scenario 'clicking on the close details bar should send the user to the event details view', js: true do
      visit activity_path(activity)
      click_link 'You are viewing activity details. Click to close.'
      expect(current_path).to eql event_path(event)
    end

    scenario "can see all the info of a venue's activity", js: true do
      venue = create(:venue, company: company, place: place)
      venue_activity = create(:activity,
                              company_user: company_user, activitable: venue,
                              campaign: campaign, activity_type: create(:activity_type,
                                                                        name: 'Test ActivityType',
                                                                        company: company,
                                                                        campaign_ids: [campaign.id]))
      visit activity_path(venue_activity)
      expect(page).to have_selector('h2', text: 'Test ActivityType')
      expect(page).to have_link(venue.name)
      expect(page).to have_content("#{place.street}, #{place.city}, #{place.state_code}, #{place.zipcode}")
      expect(current_path).to eql activity_path(venue_activity)
    end

    scenario 'can see the info of activities in the event details', js: true do
      campaign.activity_types << create(:activity_type, company: company)
      activity

      visit event_path(event)

      within("#activity_#{activity.id}") do
        expect(page).to have_content('Test ActivityType')
        expect(page).to have_content('THU Aug 21, 2014')
        expect(page).to have_content(company_user.full_name)
      end
    end

    scenario 'can see the info of activities in the venues details', js: true do
      venue = create(:venue, company: company, place: place)
      venue_activity = create(:activity,
                              company_user: company_user, activitable: venue, activity_date: '08/21/2014',
                              campaign: campaign, activity_type: create(:activity_type,
                                                                        name: 'Test ActivityType',
                                                                        company: company,
                                                                        campaign_ids: [campaign.id]))
      campaign.activity_types << create(:activity_type, company: company)

      visit venue_path(venue)

      within("#activity_#{venue_activity.id}") do
        expect(page).to have_content('Test ActivityType')
        expect(page).to have_content('THU Aug 21, 2014')
        expect(page).to have_content(company_user.full_name)
        expect(page).to have_content(venue_activity.campaign.name)
      end
    end
  end

  feature 'admin user', js: true do
    let(:role) { create(:role, company: company) }

    scenario 'should not display the activities section if the campaigns have no activity types assigned' do
      visit event_path(event)
      expect(page).to_not have_css('#event-activities')

      campaign.activity_types << create(:activity_type, company: company)

      visit event_path(event)
      expect(page).to have_css('#event-activities')
    end

    scenario 'allows the user to add an activity to an Event, see it displayed in the Activities list and then deactivate it' do
      expect_any_instance_of(CombinedSearch).to receive(:open).and_return(double(read: { results:
        [
          { reference: 'xxxxx', place_id: '1111', name: 'Walt Disney World Dolphin',
            formatted_address: '1500 Epcot Resorts Blvd, Lake Buena Vista, Florida, United States' }
        ]
      }.to_json))
      expect_any_instance_of(GooglePlaces::Client).to receive(:spot).with('xxxxx').and_return(double(
        name: 'Walt Disney World Dolphin', formatted_address: '1500 Epcot Resorts Blvd',
        lat: '1.1111', lng: '2.2222', types: ['establishment'], reference: 'xxxxx', id: '1111',
        address_components: [
          { 'types' => ['country'], 'short_name' => 'US' },
          { 'types' => ['administrative_area_level_1'], 'short_name' => 'FL', 'long_name' => 'Florida' },
          { 'types' => ['locality'], 'long_name' => 'Lake Buena Vista' },
          { 'types' => ['route'], 'long_name' => '1500 Epcot Resorts Blvd' }
        ]
      ))

      create(:user, company: company, first_name: 'Juanito', last_name: 'Bazooka')
      brand1 = create(:brand, name: 'Brand #1', company: company)
      brand2 = create(:brand, name: 'Brand #2', company: company)
      create(:marque, name: 'Marque #1 for Brand #2', brand: brand2)
      create(:marque, name: 'Marque #2 for Brand #2', brand: brand2)
      create(:marque, name: 'Marque alone', brand: brand1)
      campaign.brands << brand1
      campaign.brands << brand2

      activity_type = create(:activity_type, name: 'Activity Type #1', company: company)
      create(:form_field, name: 'Brand', type: 'FormField::Brand', fieldable: activity_type, ordering: 1)
      create(:form_field, name: 'Marque', type: 'FormField::Marque', fieldable: activity_type, ordering: 2, settings: { 'multiple' => true })
      create(:form_field, name: 'Form Field #1', type: 'FormField::Number', fieldable: activity_type, ordering: 3)
      dropdown_field = create(:form_field, name: 'Form Field #2', type: 'FormField::Dropdown', fieldable: activity_type, ordering: 4)
      create(:form_field_option, name: 'Dropdown option #1', form_field: dropdown_field, ordering: 1)
      create(:form_field_option, name: 'Dropdown option #2', form_field: dropdown_field, ordering: 2)
      create(:form_field, name: 'Place Field', type: 'FormField::Place', fieldable: activity_type, ordering: 5)

      activity_type2 = create(:activity_type, name: 'Activity Type #2', company: company)
      create(:form_field, name: 'Form Field #1', type: 'FormField::Number', fieldable: activity_type2, ordering: 3)

      campaign.activity_types << [activity_type, activity_type2]

      visit event_path(event)

      expect(page).to_not have_content('Activity Type #1')

      click_js_button 'Add Activity'

      within visible_modal do
        choose('Activity Type #1')
        click_js_button 'Create'
      end

      within('.survey-header') do
        expect(page).to have_content 'Activity Type #1'
      end

      select_from_chosen('Brand #2', from: 'Brand')
      wait_for_ajax
      select_from_chosen('Marque #1 for Brand #2', from: 'Marque')
      fill_in 'Form Field #1', with: '122'
      select_from_chosen('Dropdown option #2', from: 'Form Field #2')
      select_from_chosen('Juanito Bazooka', from: 'User')
      fill_in 'Date', with: '05/16/2013'
      select_from_autocomplete 'Search for a place', 'Walt Disney World Dolphin'

      click_button 'Submit'

      expect(page).to have_content('Thank You!')

      click_link 'Finish'
      expect(page).to have_content 'Nice work. One Activity Type #1 activity has been added.'

      within resource_item do
        expect(page).to have_content('Juanito Bazooka')
        expect(page).to have_content('THU May 16')
        expect(page).to have_content('Activity Type #1')
        click_js_link('Activity Details')
      end

      # Test the activity details page
      expect(page).to have_selector('.details-main-title', text: 'Activity Type #1')
      expect(page).to have_content('Juanito Bazooka')
      expect(page).to have_content('THU May 16')
      expect(page).to have_content('Activity Type #1')
      expect(page).to have_content('Walt Disney World Dolphin, 1500 Epcot Resorts Blvd')

      visit event_path(event)

      within resource_item do
        expect(page).to have_content('Juanito Bazooka')
        expect(page).to have_content('THU May 16')
        expect(page).to have_content('Activity Type #1')
        click_js_link('Deactivate')
      end

      confirm_prompt 'Are you sure you want to deactivate this activity?'
      expect(page).to have_content 'Your Activity Type #1 activity has been deactivated'
      within('#activities-list') do
        expect(page).to have_no_selector('li')
      end
    end

    scenario 'user can repeat or select new activity type' do
      create(:user, company: company, first_name: 'Juanito', last_name: 'Bazooka')

      activity_type = create(:activity_type, name: 'Activity Type #1', company: company)
      create(:form_field, name: '# bottles depleted', type: 'FormField::Number', fieldable: activity_type, ordering: 3)

      activity_type2 = create(:activity_type, name: 'Activity Type #2', company: company)
      create(:form_field, name: '# t-shirts given', type: 'FormField::Number', fieldable: activity_type2, ordering: 3)

      campaign.activity_types << [activity_type, activity_type2]

      visit event_path(event)

      expect(page).to_not have_content('Activity Type #1')

      click_js_button 'Add Activity'

      within visible_modal do
        choose('Activity Type #1')
        click_js_button 'Create'
      end

      within('.survey-header') do
        expect(page).to have_content 'Activity Type #1'
      end

      fill_in '# bottles depleted', with: '122'
      select_from_chosen('Juanito Bazooka', from: 'User')
      fill_in 'Date', with: '05/16/2013'

      click_button 'Submit'

      expect(page).to have_content('Thank You!')
      expect(page).to have_button('Repeat Activity')
      expect(page).to have_button('New Activity')

      click_js_button 'Repeat Activity'

      within('.survey-header') do
        expect(page).to have_content 'Activity Type #1'
      end

      fill_in '# bottles depleted', with: '122'
      select_from_chosen('Juanito Bazooka', from: 'User')
      fill_in 'Date', with: '05/16/2013'

      click_button 'Submit'
      expect(page).to have_content('Thank You!')

      #
      # Create an acitivity of a different kind
      click_js_button 'New Activity'
      within visible_modal do
        choose('Activity Type #2')
        click_js_button 'Create'
      end

      fill_in '# t-shirts given', with: '122'
      select_from_chosen('Juanito Bazooka', from: 'User')
      fill_in 'Date', with: '05/16/2013'

      click_button 'Submit'

      expect(page).to have_content('Thank You!')
      click_js_link 'Finish'
      expect(page).to have_content 'Activity Type #1'
      expect(page).to have_content 'Activity Type #2'
    end

    scenario 'allows the user to edit an activity from an Event' do
      create(:user, company: company, first_name: 'Juanito', last_name: 'Bazooka')
      brand = create(:brand, name: 'Unique Brand')
      create(:marque, name: 'Marque #1 for Brand', brand: brand)
      create(:marque, name: 'Marque #2 for Brand', brand: brand)
      campaign.brands << brand

      activity_type = create(:activity_type, name: 'Activity Type #1', company: company)
      campaign.activity_types << activity_type

      activity = create(:activity,
                        activity_type: activity_type, activitable: event,
                        campaign: campaign, company_user: company_user,
                        activity_date: '08/21/2014')

      visit event_path(event)

      hover_and_click(resource_item(activity), 'Edit')

      select_from_chosen('Juanito Bazooka', from: 'User')
      fill_in 'Date', with: '05/16/2013'
      click_button 'Save'

      within resource_item do
        expect(page).to have_content('Juanito Bazooka')
        expect(page).to have_content('THU May 16')
        expect(page).to have_content('Activity Type #1')
      end
    end

    scenario 'allows the user to add and remove place in Add activity' do
      expect_any_instance_of(CombinedSearch).to receive(:open).and_return(double(read: { results:
        [
          { reference: 'xxxxx', place_id: '1111', name: 'Walt Disney World Dolphin',
            formatted_address: '' }
        ]
      }.to_json))
      expect_any_instance_of(GooglePlaces::Client).to receive(:spot).with('xxxxx').and_return(double(
        name: 'Walt Disney World Dolphin', formatted_address: '1500 Epcot Resorts Blvd',
        lat: '1.1111', lng: '2.2222', types: ['establishment'], reference: 'xxxxx', id: '1111',
        address_components: [
          { 'types' => ['country'], 'short_name' => 'US' },
          { 'types' => ['administrative_area_level_1'], 'short_name' => 'FL', 'long_name' => 'Florida' },
          { 'types' => ['locality'], 'long_name' => 'Lake Buena Vista' },
          { 'types' => ['route'], 'long_name' => '1500 Epcot Resorts Blvd' }
        ]
      ))

      create(:user, company: company, first_name: 'Juanito', last_name: 'Bazooka')
      venue = create(:venue, company: company, place: place)
      activity_type = create(:activity_type, name: 'Activity Type #1', company: company)
      campaign.activity_types << activity_type
      create(:form_field, name: 'Place Field', type: 'FormField::Place', fieldable: activity_type, ordering: 1)

      visit venue_path(venue)

      click_js_button 'Add Activity'

      within visible_modal do
        choose('Activity Type #1')
        click_js_button 'Create'
      end
      select_from_chosen(campaign.name, from: 'Campaign')
      select_from_autocomplete 'Search for a place', 'Walt Disney World Dolphin'

      expect(find('.places-autocomplete').value).to have_content('Walt Disney World Dolphin')

      click_button 'Submit'
      click_link 'Finish'

      within resource_item do
        click_js_link('Activity Details')
      end

      expect(page).to have_content('Walt Disney World Dolphin')

      visit venue_path(venue)

      within resource_item do
        click_js_link('Edit')
      end

      field = find_field('Search for a place')
      page.execute_script %{$('##{field['id']}').val('Bar la Unión').keydown().blur()}

      click_button 'Save'

      within resource_item do
        click_js_link('Activity Details')
      end

      expect(page).to have_content('Walt Disney World Dolphin')

      visit venue_path(venue)

      within resource_item do
        click_js_link('Edit')
      end

      field = find_field('Search for a place')
      page.execute_script %{$('##{field['id']}').val('').keydown().blur()}

      click_button 'Save'

      within resource_item do
        click_js_link('Activity Details')
      end

      expect(page).to_not have_content('Walt Disney World Dolphin')
    end

    scenario 'allows the user to add an activity to a Venue, see it displayed in the Activities list and then deactivate it', search: true do
      venue = create(:venue, company: company, place: create(:place, is_custom_place: true, reference: nil))
      create(:user, company: company, first_name: 'Juanito', last_name: 'Bazooka')
      campaign = create(:campaign, name: 'Campaign #1', company: company)
      brand1 = create(:brand, name: 'Brand #1', company: company)
      brand2 = create(:brand, name: 'Brand #2', company: company)
      create(:marque, name: 'Marque #1 for Brand #2', brand: brand2)
      create(:marque, name: 'Marque #2 for Brand #2', brand: brand2)
      create(:marque, name: 'Marque alone', brand: brand1)
      campaign.brands << brand1
      campaign.brands << brand2

      activity_type = create(:activity_type, name: 'Activity Type #1', company: company)
      create(:form_field, name: 'Brand', type: 'FormField::Brand', fieldable: activity_type, ordering: 1)
      create(:form_field, name: 'Marque', type: 'FormField::Marque', fieldable: activity_type, ordering: 2, settings: { 'multiple' => true })
      create(:form_field, name: 'Form Field #1', type: 'FormField::Number', fieldable: activity_type, ordering: 3)
      dropdown_field = create(:form_field, name: 'Form Field #2', type: 'FormField::Dropdown', fieldable: activity_type, ordering: 4)
      create(:form_field_option, name: 'Dropdown option #1', form_field: dropdown_field, ordering: 1)
      create(:form_field_option, name: 'Dropdown option #2', form_field: dropdown_field, ordering: 2)
      Sunspot.commit

      campaign.activity_types << activity_type

      visit venue_path(venue)

      expect(page).to_not have_content 'Activity Type #1'

      click_js_button 'Add Activity'

      within visible_modal do
        choose('Activity Type #1')
        click_js_button 'Create'
      end
      ensure_modal_was_closed

      within('.survey-header') do
        expect(page).to have_content 'Activity Type #1'
      end

      select_from_chosen('Campaign #1', from: 'Campaign')
      select_from_chosen('Brand #2', from: 'Brand')
      select_from_chosen('Marque #1 for Brand #2', from: 'Marque')
      fill_in 'Form Field #1', with: '122'
      select_from_chosen('Dropdown option #2', from: 'Form Field #2')
      select_from_chosen('Juanito Bazooka', from: 'User')
      fill_in 'Date', with: '05/16/2013'
      click_button 'Submit'

      ensure_modal_was_closed

      expect(page).to have_content('Thank You!')
      click_link 'Finish'

      within resource_item do
        expect(page).to have_content('Juanito Bazooka')
        expect(page).to have_content('THU May 16')
        expect(page).to have_content('Activity Type #1')
        click_js_link 'Deactivate'
      end

      confirm_prompt 'Are you sure you want to deactivate this activity?'

      within('#activities-list') do
        expect(page).to have_no_selector('li')
      end
    end

    scenario 'user can insert data for percentage fields' do
      activity_type = create(:activity_type, name: 'Activity Type #1', company: company)
      create(:form_field,
             fieldable: activity_type,
             type: 'FormField::Percentage',
             options: [
               create(:form_field_option, name: 'Option 1', ordering: 0),
               create(:form_field_option, name: 'Option 2', ordering: 1)])

      campaign.activity_types << activity_type

      visit event_path(event)

      click_js_button('Add Activity')

      within visible_modal do
        choose('Activity Type #1')
        click_js_button 'Create'
      end

      within('.survey-header') do
        expect(page).to have_content 'Activity Type #1'
      end

      fill_in 'Option 1', with: '10'
      fill_in 'Option 2', with: '90'
      select_from_chosen(user.name, from: 'User')
      fill_in 'Date', with: '05/16/2013'
      click_button 'Submit'

      expect(page).to have_content('Thank You!')
      click_link 'Finish'

      within resource_item do
        expect(page).to have_content(user.name)
        expect(page).to have_content('THU May 16')
        expect(page).to have_content('Activity Type #1')
      end
      hover_and_click resource_item, 'Edit'

      expect(find_field('Option 1').value).to eql '10'
      expect(find_field('Option 2').value).to eql '90'
    end

    scenario 'user can attach a photo to an activity', :inline_jobs do
      activity_type = create(:activity_type, name: 'Activity Type #1', company: company)
      create(:form_field, fieldable: activity_type, type: 'FormField::Photo')

      campaign.activity_types << activity_type

      visit event_path(event)

      click_js_button('Add Activity')

      within visible_modal do
        choose('Activity Type #1')
        click_js_button 'Create'
      end

      within('.survey-header') do
        expect(page).to have_content 'Activity Type #1'
      end

      expect(page).to have_content('DRAG & DROP')

      # Should validate the type of the image
      attach_file 'file', 'spec/fixtures/file.pdf'
      expect(page).to have_content('is not a valid file')

      attach_file 'file', 'spec/fixtures/photo.jpg'
      expect(page).to have_no_content('is not a valid file')
      wait_for_ajax(30) # For the image to upload to S3
      expect(page).to_not have_content('DRAG & DROP')
      find('.attachment-attached-view').hover
      within '.attachment-attached-view' do
        expect(page).to have_link('Remove')
        expect(page).to_not have_link('Download')
      end

      select_from_chosen(user.name, from: 'User')
      fill_in 'Date', with: '05/16/2013'
      wait_for_photo_to_process 30 do
        click_button 'Submit'
      end

      expect(page).to have_content('Thank You!')
      click_link 'Finish'

      within resource_item do
        expect(page).to have_content(user.name)
        expect(page).to have_content('THU May 16')
        expect(page).to have_content('Activity Type #1')
      end

      photo = AttachedAsset.last
      expect(photo.attachable).to be_a FormFieldResult
      expect(photo.file_file_name).to eql 'photo.jpg'

      # Remove the photo and attach a new one
      hover_and_click resource_item, 'Edit'

      expect(page).to_not have_content('DRAG & DROP')
      find('.attachment-attached-view').hover
      within '.attachment-attached-view' do
        expect(page).to have_link('Remove')
        expect(page).to have_link('Download')
        click_js_link('Remove')
      end
      expect(page).to have_content('DRAG & DROP')

      attach_file 'file', 'spec/fixtures/photo2.jpg'
      expect(page).to have_no_content('is not a valid file')
      wait_for_ajax(30) # For the image to upload to S3
      expect(page).to_not have_content('DRAG & DROP')
      find('.attachment-attached-view').hover
      within '.attachment-attached-view' do
        expect(page).to have_link('Remove')
        expect(page).to_not have_link('Download')
      end

      wait_for_photo_to_process 30 do
        click_button 'Save'
      end

      photo = AttachedAsset.last
      expect(photo.attachable).to be_a FormFieldResult
      expect(photo.file_file_name).to eql 'photo2.jpg'

      # Remove the photo
      hover_and_click resource_item, 'Edit'

      expect do
        expect(page).to_not have_content('DRAG & DROP')
        find('.attachment-attached-view').hover
        within '.attachment-attached-view' do
          expect(page).to have_link('Remove')
          expect(page).to have_link('Download')
          click_js_link('Remove')
        end
        expect(page).to have_content('DRAG & DROP')
        click_button 'Save'
        within resource_item do
          expect(page).to have_content('Activity Type #1')
        end
      end.to change(AttachedAsset, :count).by(-1)
    end

    scenario 'user can attach a document to an activity', :inline_jobs do
      activity_type = create(:activity_type, name: 'Activity Type #1', company: company)
      create(:form_field, fieldable: activity_type, type: 'FormField::Attachment')

      campaign.activity_types << activity_type

      visit event_path(event)

      click_js_button('Add Activity')

      within visible_modal do
        choose('Activity Type #1')
        click_js_button 'Create'
      end
      ensure_modal_was_closed

      expect(page).to have_content('DRAG & DROP')
      attach_file 'file', 'spec/fixtures/file.pdf'
      expect(page).to have_no_content('is not a valid file')
      wait_for_ajax(30) # For the file to upload to S3
      expect(page).to_not have_content('DRAG & DROP')
      expect(page).to have_content('file.pdf')
      expect(page).to have_link('Remove')

      select_from_chosen(user.name, from: 'User')
      fill_in 'Date', with: '05/16/2013'
      wait_for_photo_to_process 30 do
        click_js_button 'Submit'
      end

      expect(page).to have_content('Thank You!')
      click_link 'Finish'

      within resource_item do
        expect(page).to have_content(user.name)
        expect(page).to have_content('THU May 16')
        expect(page).to have_content('Activity Type #1')
      end

      activity = Activity.last
      photo = AttachedAsset.last
      expect(photo.attachable).to be_a FormFieldResult
      expect(photo.file_file_name).to eql 'file.pdf'

      hover_and_click resource_item, 'Activity Details'

      expect(page).to have_selector('h2', text: 'Activity Type #1')
      expect(current_path).to eql activity_path(activity)
      file = AttachedAsset.last
      src = file.reload.file.url(:original, timestamp: false).gsub(/\Ahttp(s)?/, 'https')
      expect(page).to have_xpath("//a[starts-with(@href, \"#{src}\")]")

      visit event_path(event)

      # Remove the file
      hover_and_click resource_item, 'Edit'

      expect do
        expect(page).to_not have_content('DRAG & DROP')
        click_js_link('Remove')
        expect(page).to have_content('DRAG & DROP')
        click_button 'Save'
        within resource_item do
          expect(page).to have_content('Activity Type #1')
        end
      end.to change(AttachedAsset, :count).by(-1)
    end

    scenario 'activities from events should be displayed within the venue' do
      create(:activity,
             company_user: company_user, activitable: event,
             activity_type: create(:activity_type,
                                   name: 'Test ActivityType',
                                   company: company, campaign_ids: [campaign.id]))

      visit venue_path(event.venue)

      within('#activities-list') do
        expect(page).to have_content('Test ActivityType')
      end
    end

    scenario 'allows the user to edit an activity from a Venue' do
      venue = create(:venue, company: company, place: create(:place, is_custom_place: true, reference: nil))
      create(:user, company: company, first_name: 'Juanito', last_name: 'Bazooka')
      campaign = create(:campaign, name: 'Campaign #1', company: company)
      brand = create(:brand, name: 'Unique Brand')
      create(:marque, name: 'Marque #1 for Brand', brand: brand)
      create(:marque, name: 'Marque #2 for Brand', brand: brand)
      campaign.brands << brand

      activity_type = create(:activity_type, name: 'Activity Type #1', company: company)
      campaign.activity_types << activity_type

      create(:activity, activity_type: activity_type, activitable: venue, campaign: campaign,
                        company_user: company_user, activity_date: '08/21/2014')

      visit venue_path(venue)

      hover_and_click resource_item, 'Edit'

      select_from_chosen('Juanito Bazooka', from: 'User')
      fill_in 'Date', with: '05/16/2013'
      click_button 'Save'

      within resource_item do
        expect(page).to have_content('Juanito Bazooka')
        expect(page).to have_content('THU May 16')
        expect(page).to have_content('Activity Type #1')
      end
    end
  end

  feature 'non admin user', js: true do
    let(:role) { create(:non_admin_role, company: company) }

    it_should_behave_like 'a user that view the activiy details' do
      before { company_user.campaigns << campaign }
      before { company_user.places << place }
      let(:permissions) { [[:show, 'Activity'], [:show, 'Event'], [:show, 'Venue']] }
    end
  end
end
