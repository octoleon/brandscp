require 'rails_helper'

feature 'Results Media Gallery Page', js: true, search: true do
  let(:user) { create(:user, company_id: create(:company).id, role_id: create(:role).id) }
  let(:company) { user.companies.first }
  let(:company_user) { user.current_company_user }
  let(:campaign) { create(:campaign, name: 'Campaign 1', company: company, modules: { 'photos' => {} }) }
  let(:place) { create(:place, name: 'A Nice Place', country: 'CR', city: 'Curridabat', state: 'San Jose') }
  let(:event) { create(:late_event, company: company, campaign: campaign, start_date: '02/20/2013', end_date: '02/20/2013', place: place) }

  before do
    Warden.test_mode!
    sign_in user
    Kpi.create_global_kpis
  end

  after do
    AttachedAsset.destroy_all
    Warden.test_reset!
  end

  feature 'Media Gallery Results', js: true do
    scenario 'a user can filter photos by media type in the photos report' do
      activity_type = create(:activity_type, name: 'Activity Type #1', company: company)
      campaign.activity_types << activity_type
      activity = create(:activity, activity_type: activity_type, activitable: event, campaign: campaign, company_user_id: 1)

      ff_photo = FormField.find(create(:form_field, fieldable: activity_type, type: 'FormField::Photo').id)
      activity_result = FormFieldResult.new(form_field: ff_photo, resultable: activity)

      ff_photo = FormField.find(create(:form_field, fieldable: campaign, type: 'FormField::Photo').id)
      event_result = FormFieldResult.new(form_field: ff_photo, resultable: event)

      create(:photo, attachable: activity_result, file_file_name: 'activity_photo.jpg', active: true)
      create(:photo, attachable: event_result, file_file_name: 'per_photo.jpg', active: true)
      create(:photo, attachable: event, file_file_name: 'event_photo.jpg', active: true)
      create(:video, attachable: event, file_file_name: 'event_video.flv', active: true)
      Sunspot.commit

      visit results_photos_path

      # Show only Videos
      add_filter('MEDIA TYPE', 'Video')

      expect(page).to have_selector('#photos-list .photo-item', count: 1)
      within gallery_box do
        expect(page).to_not have_css("img[alt='Activity photo']")
        expect(page).to_not have_css("img[alt='Per photo']")
        expect(page).to_not have_css("img[alt='Event photo']")
        expect(page).to have_css("img[alt='Event video']")
      end

      # Show Videos and Images
      add_filter('MEDIA TYPE', 'Image')

      expect(page).to have_selector('#photos-list .photo-item', count: 4)
      within gallery_box do
        expect(page).to have_css("img[alt='Activity photo']")
        expect(page).to have_css("img[alt='Per photo']")
        expect(page).to have_css("img[alt='Event photo']")
        expect(page).to have_css("img[alt='Event video']")
      end

      # Show only Images
      remove_filter('Video')

      expect(page).to have_selector('#photos-list .photo-item', count: 3)
      within gallery_box do
        expect(page).to have_css("img[alt='Activity photo']")
        expect(page).to have_css("img[alt='Per photo']")
        expect(page).to have_css("img[alt='Event photo']")
        expect(page).to_not have_css("img[alt='Event video']")
      end
    end

    scenario 'a user can filter photos by activity type in the photos report' do
      activity_type1 = create(:activity_type, name: 'Activity Type #1', company: company)
      activity_type2 = create(:activity_type, name: 'Activity Type #2', company: company)
      campaign.activity_types << [activity_type1, activity_type2]
      activity = create(:activity, activity_type: activity_type1, activitable: event, campaign: campaign, company_user_id: 1)
      activity2 = create(:activity, activity_type: activity_type2, activitable: event, campaign: campaign, company_user_id: 1)

      ff_photo = FormField.find(create(:form_field, fieldable: activity_type1, type: 'FormField::Photo').id)
      activity_result = FormFieldResult.new(form_field: ff_photo, resultable: activity)

      ff_photo = FormField.find(create(:form_field, fieldable: activity_type1, type: 'FormField::Photo').id)
      activity_result2 = FormFieldResult.new(form_field: ff_photo, resultable: activity2)

      ff_photo = FormField.find(create(:form_field, fieldable: campaign, type: 'FormField::Photo').id)
      event_result = FormFieldResult.new(form_field: ff_photo, resultable: event)

      create(:photo, attachable: activity_result, file_file_name: 'activity_photo1.jpg', active: true)
      create(:photo, attachable: activity_result2, file_file_name: 'activity_photo2.jpg', active: true)
      create(:photo, attachable: event_result, file_file_name: 'per_photo.jpg', active: true)
      create(:photo, attachable: event, file_file_name: 'event_photo.jpg', active: true)
      create(:photo, attachable: event, file_file_name: 'event_photo_2.jpg', active: true)

      Sunspot.commit

      visit results_photos_path

      # Show only activity type #1
      add_filter('ACTIVITY TYPE', 'Activity Type #1')

      expect(page).to have_selector('#photos-list .photo-item', count: 4)
      within gallery_box do
        expect(page).to have_css("img[alt='Activity photo1']")
        expect(page).to have_css("img[alt='Per photo']")
        expect(page).to have_css("img[alt='Event photo']")
        expect(page).to have_css("img[alt='Event photo 2']")
      end

      # Show both activity types
      add_filter('ACTIVITY TYPE', 'Activity Type #2')

      expect(page).to have_selector('#photos-list .photo-item', count: 5)
      within gallery_box do
        expect(page).to have_css("img[alt='Activity photo1']")
        expect(page).to have_css("img[alt='Activity photo2']")
        expect(page).to have_css("img[alt='Per photo']")
        expect(page).to have_css("img[alt='Event photo']")
        expect(page).to have_css("img[alt='Event photo 2']")
      end

      # Show only activity type #2
      remove_filter 'Activity Type #1'

      expect(page).to have_selector('#photos-list .photo-item', count: 4)
      within gallery_box do
        expect(page).to have_css("img[alt='Activity photo2']")
        expect(page).to have_css("img[alt='Per photo']")
        expect(page).to have_css("img[alt='Event photo']")
        expect(page).to have_css("img[alt='Event photo 2']")
      end
    end

    scenario 'a user can filter photos by campaign name in the photos report' do
      campaign2 = create(:campaign, company: company, name: 'Test Campaign', modules: { 'photos' => {} })
      event2 = create(:late_event, company: company, campaign: campaign2)
      activity_type = create(:activity_type, name: 'Activity Type #1', company: company)
      campaign2.activity_types << activity_type
      activity = create(:activity, activity_type: activity_type, activitable: event2, campaign: campaign2, company_user_id: 1)

      ff_photo = FormField.find(create(:form_field, fieldable: activity_type, type: 'FormField::Photo').id)
      activity_result = FormFieldResult.new(form_field: ff_photo, resultable: activity)

      ff_photo = FormField.find(create(:form_field, fieldable: campaign2, type: 'FormField::Photo').id)
      event_result = FormFieldResult.new(form_field: ff_photo, resultable: event2)

      create(:photo, attachable: activity_result, file_file_name: 'activity_photo.jpg', active: true)
      create(:photo, attachable: event_result, file_file_name: 'per_photo.jpg', active: true)
      create(:photo, attachable: event2, file_file_name: 'event_photo.jpg', active: true)
      create(:video, attachable: event, file_file_name: 'event_video.flv', active: true)
      Sunspot.commit

      visit results_photos_path

      # Show only items for Campaign 1
      add_filter('CAMPAIGNS', 'Campaign 1')

      expect(page).to have_selector('#photos-list .photo-item', count: 1)
      within gallery_box do
        expect(page).to_not have_css("img[alt='Activity photo']")
        expect(page).to_not have_css("img[alt='Per photo']")
        expect(page).to_not have_css("img[alt='Event photo']")
        expect(page).to have_css("img[alt='Event video']")
      end

      # Show items for Campaign 1 and Test Campaign
      add_filter('CAMPAIGNS', 'Test Campaign')

      expect(page).to have_selector('#photos-list .photo-item', count: 4)
      within gallery_box do
        expect(page).to have_css("img[alt='Activity photo']")
        expect(page).to have_css("img[alt='Per photo']")
        expect(page).to have_css("img[alt='Event photo']")
        expect(page).to have_css("img[alt='Event video']")
      end

      # Show only items for Test Campaign
      remove_filter 'Campaign 1'

      expect(page).to have_selector('#photos-list .photo-item', count: 3)
      within gallery_box do
        expect(page).to have_css("img[alt='Activity photo']")
        expect(page).to have_css("img[alt='Per photo']")
        expect(page).to have_css("img[alt='Event photo']")
        expect(page).to_not have_css("img[alt='Event video']")
      end
    end
  end

  def gallery_box
    page.find('.gallery.photoGallery')
  end

  def gallery_modal
    page.find('.gallery-modal')
  end

  def gallery_item(resource = 1)
    item = page.find(".photo-item:nth-child(#{resource})")
    begin
      item.hover
    rescue Capybara::Poltergeist::MouseEventFailed
      page.evaluate_script 'window.scrollBy(0, -100);'
      item.hover
    end
    item
  end
end
