require 'rails_helper'

feature 'Roles', js: true do
  let(:company) { create(:company) }
  let(:user) { create(:user, company_id: company.id, role_id: create(:role, name: 'Role 1', company: company).id) }
  let(:company_user) { user.company_users.first }

  before { sign_in user }
  after { Warden.test_reset! }

  feature '/roles', search: true do
    scenario 'GET index should display a list with the roles' do
      create(:role, name: 'Costa Rica Role',
        description: 'el grupo de ticos', active: true, company_id: company.id)
      create(:role, name: 'Buenos Aires Role',
        description: 'the guys from BAs', active: true, company_id: company.id)
      Sunspot.commit

      visit roles_path

      # First Row
      within resource_item 1 do
        expect(page).to have_content('Buenos Aires Role')
        expect(page).to have_content('the guys from BAs')
      end
      # Second Row
      within resource_item 2 do
        expect(page).to have_content('Costa Rica Role')
        expect(page).to have_content('el grupo de ticos')
      end
    end

    scenario 'allows the user to activate/deactivate roles' do
      create(:role, name: 'Costa Rica Role', description: 'el grupo de ticos', active: true, company: company)
      Sunspot.commit

      visit roles_path

      within resource_item 1 do
        expect(page).to have_content('Costa Rica Role')
        click_js_button 'Deactivate Role'
      end

      confirm_prompt 'Costa Rica Role users can no longer login if you deactivate that role. Would you like to continue?'

      within('#roles-list') do
        expect(page).to have_no_content('Costa Rica Role')
      end

      # Make it show only the inactive elements
      add_filter 'ACTIVE STATE', 'Inactive'
      remove_filter 'Active'

      expect(page).to have_content '1 role found for: Inactive'

      within resource_item 1 do
        expect(page).to have_content('Costa Rica Role')
        click_js_button 'Activate Role'
      end
      expect(page).to have_no_content('Costa Rica Role')
    end

    scenario 'allows the user to create a new role' do
      visit roles_path

      click_js_button 'New Role'

      within visible_modal do
        fill_in 'Name', with: 'new role name'
        fill_in 'Description', with: 'new role description'
        click_button 'Create'
      end
      ensure_modal_was_closed

      expect(page).to have_selector('h2', text: 'new role name')
      expect(page).to have_selector('div.description-data', text: 'new role description')
    end
  end

  feature '/roles/:role_id', js: true do
    scenario 'GET show should display the role details page' do
      role = create(:role, name: 'Some Role Name', description: 'a role description', company_id: company.id)
      visit role_path(role)
      expect(page).to have_selector('h2', text: 'Some Role Name')
      expect(page).to have_selector('div.description-data', text: 'a role description')
    end

    scenario 'allows the user to activate/deactivate a role' do
      role = create(:role, name: 'Admin', active: true, company_id: company.id)
      visit role_path(role)
      within('.edition-links') do
        click_js_button 'Deactivate Role'
      end

      confirm_prompt 'Admin users can no longer login if you deactivate that role. Would you like to continue?'

      within('.edition-links') do
        click_js_button 'Activate Role'
        expect(page).to have_button 'Deactivate Role' # test the link have changed
      end
    end

    scenario 'allows the user to edit the role' do
      role = create(:role, company_id: company.id)
      Sunspot.commit
      visit role_path(role)

      within('.edition-links') { click_js_button 'Edit Role' }

      within visible_modal do
        fill_in 'Name', with: 'edited role name'
        fill_in 'Description', with: 'edited role description'
        click_js_button 'Save'
      end
      ensure_modal_was_closed

      expect(page).to have_selector('h2', text: 'edited role name')
      expect(page).to have_selector('div.description-data', text: 'edited role description')
    end
  end

  it_behaves_like 'a list that allow saving custom filters' do

    let(:list_url) { roles_path }

    let(:filters) do
      [{ section: 'ACTIVE STATE', item: 'Inactive' }]
    end
  end

  feature 'export', search: true do
    let(:role1) { create(:role, name: 'Costa Rica Role', description: 'El grupo de ticos', active: true, company: company) }
    let(:role2) { create(:role, name: 'Buenos Aires Role', description: 'The guys from BAs', active: true, company: company) }

    before do
      # make sure roles are created before
      role1
      role2
      Sunspot.commit
    end

    scenario 'should be able to export as CSV' do
      visit roles_path

      click_js_link 'Download'
      click_js_link 'Download as CSV'

      wait_for_export_to_complete

      expect(ListExport.last).to have_rows([
        ['NAME', 'DESCRIPTION', 'ACTIVE STATE'],
        ['Buenos Aires Role', 'The guys from BAs', 'Active'],
        ['Costa Rica Role', 'El grupo de ticos', 'Active'],
        ['Role 1', 'Test Role description', 'Active']
      ])
    end

    scenario 'should be able to export as PDF' do
      visit roles_path

      click_js_link 'Download'
      click_js_link 'Download as PDF'

      wait_for_export_to_complete

      # Test the generated PDF...
      reader = PDF::Reader.new(open(ListExport.last.file.url))
      reader.pages.each do |page|
        # PDF to text seems to not always return the same results
        # with white spaces, so, remove them and look for strings
        # without whitespaces
        text = page.text.gsub(/[\s\n]/, '')
        expect(text).to include 'Roles'
        expect(text).to include 'BuenosAiresRole'
        expect(text).to include 'TheguysfromBAs'
        expect(text).to include 'CostaRicaRole'
        expect(text).to include 'Elgrupodeticos'
        expect(text).to include 'Role1'
        expect(text).to include 'TestRoledescription'
      end
    end
  end

  def roles_list
    '#roles-list'
  end
end
