require 'rails_helper'

feature 'SatisfactionSurvey', js: true do

  before do
    Warden.test_mode!
    @user = create(:user, company_id: create(:company).id, role_id: create(:role).id)
    sign_in @user
  end

  after do
    Warden.test_reset!
  end

  feature 'Satisfaction Survey' do
    scenario 'can rate satisfaction and write a feedback' do
      visit root_path

      expect(page).to have_content('Overall how do you feel about the app?')
      expect(page).to have_no_content('Would you like to give us some feedback?')

      within emotions_box do
        expect(find('input#emotion_positive')).not_to be_checked
        choose('emotion_positive')
        expect(find('input#emotion_positive')).to be_checked
      end

      expect(page).to have_content('Would you like to give us some feedback?')

      within feedback_box do
        fill_in 'feedback', with: 'This is my happy feedback'
        click_js_button 'Send'
      end

      expect(page).to have_content('Thanks!')

      # Reload page and make sure the selected emoticon remains selected
      visit root_path

      within emotions_box do
        expect(find('input#emotion_positive')).to be_checked
      end
    end
  end

  def emotions_box
    find('.emotions_select')
  end

  def feedback_box
    find('.survey-box')
  end
end
