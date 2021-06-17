require 'rails_helper'

feature 'User Profile', js: true do
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

  shared_examples_for 'a user that can view his profile' do
    scenario 'should be able to confirm his number' do
      visit root_path
      click_link user.full_name
      click_link 'View Profile'
      click_link 'Get Verified'
      within visible_modal do
        expect(page).to have_content('Send security code')
        expect(page).to have_content("We will send you a message to #{user.phone_number} with a code.")
        click_button 'Send'
      end

      expect(page).to_not have_content('We will send you a message to')

      within visible_modal do
        expect(page).to have_content('Verify mobile phone number')
        expect(page).to have_content("Enter the security code you've received into the filed below.")
        fill_in '6-digit code', with: user.reload.phone_number_verification
        click_button 'Verify'
      end
      ensure_modal_was_closed

      expect(user.reload.phone_number_verified).to be_truthy

      expect(page).to have_content 'Verified'
    end
  end

  feature 'Non-Admin User' do
    let(:role) { create(:non_admin_role, company: company) }

    it_behaves_like 'a user that can view his profile'
  end

end
