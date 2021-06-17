require 'rails_helper'

feature 'As a Super Admin, I want to login as another system user' do
  let(:company) { create(:company, name: 'JUSTICE INC') }
  let(:campaign) { create(:campaign, company: company) }
  let(:user) { create(:user, company: company, role_id: role.id) }
  let(:company_user) { user.company_users.first }
  let(:place) { create(:place, name: 'A Nice Place', country: 'CR', city: 'Curridabat', state: 'San Jose') }
  let(:permissions) { [] }
  let(:event) { create(:event, campaign: campaign, company: company) }

  before do
    Warden.test_mode!
    sign_in user
  end
  after do
    Warden.test_reset!
  end

  feature 'admin user', js: true, search: true  do
    let(:role) { create(:role, company: company) }
    let(:role2) { create(:non_admin_role, company: company) }

    let(:events)do
      [
        create(:event,
               start_date: '08/21/2013', end_date: '08/21/2013',
               start_time: '10:00am', end_time: '11:00am',
               campaign: campaign, active: true,
               place: create(:place, name: 'Campaign #1 FY2012')),
        create(:event,
               start_date: '08/28/2013', end_date: '08/29/2013',
               start_time: '11:00am', end_time: '12:00pm',
               campaign: create(:campaign, name: 'Campaign #2 FY2012', company: company),
               place: create(:place, name: 'Place 2'), company: company)
      ]
    end

    scenario 'a user that view custom user navigation' do

      events[0].users << create(:company_user,
                                user: create(:user, first_name: 'Roberto', last_name: 'Gomez'), company: company, role_id: role2.id)
      events[1].users << create(:company_user,
                                user: create(:user, first_name: 'Mario', last_name: 'Cantinflas'), company: company)
      events  # make sure events are created before
      Sunspot.commit

      visit events_path

      expect(page).to have_selector('.top-admin-login-navigation', count: 1)
      expect(page).to have_selector('li#admin', count: 1)
      expect(page).to have_content('VENUES')

      click_button 'Login as specific user'

      expect(page).to have_content('Choose a user that you want to login as')
      select_from_chosen 'Roberto Gomez', from: 'Choose a user that you want to login as'

      click_button 'Login'

      expect(page).to have_content('You are logged in as Roberto Gomez')
      expect(page).to_not have_content('VENUES')
      expect(page).to_not have_selector('li#admin')

      click_button 'Login as Super Admin'

      expect(page).to have_content('You are logged as a Super Admin.')
      expect(page).to have_button('Login as specific user')
      expect(page).to have_selector('li#admin', count: 1)
      expect(page).to have_content('VENUES')
    end

    scenario 'user can cancel login with other user' do
      visit events_path

      expect(page).to have_selector('.top-admin-login-navigation', count: 1)

      click_button 'Login as specific user'

      expect(page).to have_selector('#cancel-login-specific-user')

      click_button 'Cancel'

      expect(page).to_not have_selector('#cancel-login-specific-user')
      expect(page).to have_button('Login as specific user')
    end

    scenario 'user cannot switch to companies that are not accesible by him' do
      create(:company_user, user: create(:user, first_name: 'Roberto', last_name: 'Gomez'),
                            company: company, role_id: role2.id)

      # A user in two companies
      company2 = create(:company, name: 'FOBAR INC')
      user = create(:user, first_name: 'Mario', last_name: 'Cantinflas')
      create(:company_user, user: user, company: company)
      create(:company_user, user: user, company: company2)
      user.current_company = company2
      user.save

      Sunspot.commit

      visit root_path

      click_button 'Login as specific user'

      select_from_chosen 'Mario Cantinflas', from: 'Choose a user that you want to login as'
      click_button 'Login'

      expect(page).to have_content('You are logged in as Mario Cantinflas')
      expect(page).to_not have_content('FOBAR INC')
      expect(page).to have_content('JUSTICE INC')
      expect(page).to_not have_selector('.dropdown-toggle.current-company-title')
    end
  end

  feature 'non admin user', js: true  do
    let(:role) { create(:non_admin_role, company: company) }

    scenario 'a user that not view custom user navigation' do
      visit events_path
      expect(page).to_not have_selector('.top-admin-login-navigation')
    end
  end
end
