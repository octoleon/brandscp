require 'rails_helper'

feature 'Photos', js: true do
  let(:company) { create(:company) }
  let(:role) { create(:role, company: company) }
  let(:user) { create(:user, company_id: company.id, role_id: role.id) }
  let(:campaign) { create(:campaign, company: company, modules: { 'photos' => {} }) }
  let(:event) { create(:late_event, company: company, campaign: campaign) }

  before do
    Warden.test_mode!
    sign_in user
    Kpi.create_global_kpis
  end

  after do
    AttachedAsset.destroy_all
    Warden.test_reset!
  end

  feature 'Event Photo management' do
    scenario 'A user can select a photo and attach it to the event', :inline_jobs do
      visit event_path(event)

      within '#event-photos' do
        attach_file 'file', 'spec/fixtures/photo.jpg'
        expect(page).to have_content('photo.jpg')
        wait_for_ajax(30) # For the image to upload to S3
      end

      photo = AttachedAsset.last
      # Check that the image appears on the page
      within gallery_box do
        src = photo.file.url(:thumbnail, timestamp: false)
        expect(page).to have_xpath("//img[starts-with(@src, \"#{src}\")]", wait: 10)
      end
    end

    scenario 'A user can deactivate a photo' do
      create(:photo, attachable: event)
      visit event_path(event)

      # Check that the image appears on the page
      within gallery_box do
        expect(page).to have_selector('li.photo-item')
        hover_and_click 'li.photo-item', 'Deactivate'
      end

      confirm_prompt 'Are you sure you want to deactivate this photo?'
      expect(gallery_box).to have_no_selector('li.photo-item')
    end
  end

  feature 'Photo Gallery' do
    scenario 'Should display only active photos in Event Gallery' do
      create(:photo, attachable: event)
      create(:photo, attachable: event, active: false)

      visit event_path(event)

      # Check that just one image appears on the page
      within gallery_box do
        expect(page.all('li.photo-item').count).to eql(1)
      end
    end

    scenario 'create correctly each item in the media gallery' do
      create(:video, attachable: event)
      create(:photo, attachable: event)

      visit event_path(event)

      find('.photo-item:nth-child(1)').hover
      within '.photo-item:nth-child(1)' do
        expect(page).to have_link('Download Photo')
        expect(page).to have_no_selector('.thumbnail-circle')
      end

      find('.photo-item:nth-child(2)').hover
      within '.photo-item:nth-child(2)' do
        expect(page).to have_link('Download Video')
        expect(page).to have_selector('.thumbnail-circle')
      end
    end

    scenario 'can rate a photo' do
      photo = create(:photo, attachable: event, rating: 2)
      visit event_path(event)

      # Check that the image appears on the page
      within gallery_box do
        expect(page).to have_selector('li')
        click_js_link 'View Photo'
      end

      within gallery_modal do
        find('.rating span.icon-star', match: :first)
        expect(page.all('.rating span.icon-star').count).to eql(2)
        expect(page.all('.rating span.icon-wired-star').count).to eql(3)
        find('.rating span:nth-child(3)').trigger('click')
        wait_for_ajax
        expect(photo.reload.rating).to eql 3
        click_js_link 'Close'
      end
      ensure_modal_was_closed

      # Close the modal and reopened and make sure the stars are correctly
      # highlithed
      within gallery_box do
        click_js_link 'View Photo'
      end
      within gallery_modal do
        find('.rating span.icon-star', match: :first)
        expect(page.all('.rating span.icon-star').count).to eql(3)
        expect(page.all('.rating span.icon-wired-star').count).to eql(2)
      end
    end

    scenario 'a user can deactivate a photo' do
      create(:photo, attachable: event)
      visit event_path(event)

      # Check that the image appears on the page
      within gallery_box do
        expect(page).to have_selector('li')
        click_js_link 'View Photo'
      end

      # Deactivate the image from the link inside the gallery modal
      within gallery_modal do
        hover_and_click('.slider', 'Deactivate')
      end

      confirm_prompt 'Are you sure you want to deactivate this photo?'

      within gallery_modal do
        expect(page).to have_no_selector('a.photo-deactivate-link')
      end

      expect(gallery_box).to have_no_selector('a.photo-deactivate-link')
    end

    scenario 'a user can navigate between Gallery modal items' do
      photo1 = create(:photo, attachable: event)
      photo2 = create(:photo, attachable: event)

      visit event_path(event)

      # Check that the images appear on the page
      within gallery_box do
        expect(page).to have_selector('li.photo-item', count: 2)
        # Last child is the first item uploaded
        within('li.photo-item:nth-child(2)') { click_js_link 'View Photo' }
      end

      # Navigate between items inside the gallery modal
      within gallery_modal do
        within slider_active_item do
          expect(page).to have_selector("img#img_#{photo1.id}")
        end

        carousel_navigate('right')

        within slider_active_item do
          expect(page).to have_selector("img#img_#{photo2.id}")
        end

        carousel_navigate('left')

        within slider_active_item do
          expect(page).to have_selector("img#img_#{photo1.id}")
        end
      end
    end

    scenario 'a user do not see blank state message when photos from Events Galleries, PERs and Activities in the photos report are there', search: true do
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
      Sunspot.commit

      visit results_photos_path

      expect(page).to have_selector('#photos-list .photo-item', count: 3)
      expect(page).not_to have_selector('.blank-state')
      within '#photos-list' do
        expect(page).to have_css("img[alt='Activity photo']")
        expect(page).to have_css("img[alt='Per photo']")
        expect(page).to have_css("img[alt='Event photo']")
      end
    end

    scenario 'a user see blank state message when photos are not searched by filter', search: true do
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
      Sunspot.commit

      visit results_photos_path

      # Make it show only the inactive elements
      add_filter 'ACTIVE STATE', 'Inactive'
      remove_filter 'Active'

      expect(page).to have_selector('.blank-state')
    end

    scenario 'a user can tag photos' do
      create(:photo, attachable: event)
      visit event_path(event)

      within gallery_box do
        click_js_link 'View Photo'
      end

      within gallery_modal do
        select2_add_tag 'Add tags', 'tag1'
        expect(find('.tags .list')).to have_content 'tag1'

        click_js_link 'Close'
      end

      within gallery_box do
        click_js_link 'View Photo'
      end

      within gallery_modal do
        within find('.tags .list .tag') do
          expect(page).to have_content 'tag1'
          click_js_link 'Remove Tag'
          wait_for_ajax
        end
      end

      within gallery_modal do
        expect(page).to have_no_content 'tag1'
        click_js_link 'Close'
      end

      within gallery_box do
        click_js_link 'View Photo'
      end

      within gallery_modal do
        expect(find('.tags .list')).to have_no_content 'tag1'
      end
    end
  end

  def gallery_box
    find('.details_box.box_photos')
  end

  def gallery_modal
    find('.gallery-modal')
  end

  def slider_active_item(mini_slider = false)
    slider = mini_slider ? 'mini-slider' : 'slider'
    find(".#{slider} .item.active")
  end

  def carousel_navigate(direction = 'right', mini_slider = false)
    slider = mini_slider ? 'mini-slider' : 'slider'
    find(".#{slider} a.carousel-control.#{direction}").trigger('click')
  end
end
