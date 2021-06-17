require 'rails_helper'

feature 'Login', js: true do
  let(:company) { create(:company, name: 'ABC inc.') }

  scenario 'should redirect the user to the login page' do
    visit root_path

    expect(current_path).to eq(new_user_session_path)
    expect(page).to have_content('You need to sign in or sign up before continuing.')
  end

  scenario 'A valid user can login' do
    user = create(:user,
                  company_id: company.id,
                  email: 'pedrito-picaso@gmail.com',
                  password: 'SomeValidPassword01',
                  password_confirmation: 'SomeValidPassword01',
                  role_id: create(:role, company: company).id)

    visit new_user_session_path
    fill_in('user[email]', with: 'pedrito-picaso@gmail.com')
    fill_in('Password', with: 'SomeValidPassword01')
    click_button 'Login'

    expect(current_path).to eq(root_path)
    expect(page).to have_text('ABC inc.')
    expect(page).to have_text(user.full_name)
  end

  scenario 'A deactivatd user cannot login' do
    create(:user,
           company_id: company.id,
           email: 'pedrito-picaso@gmail.com',
           password: 'SomeValidPassword01',
           password_confirmation: 'SomeValidPassword01',
           active: false,
           role_id: create(:role, company: company).id)

    visit new_user_session_path
    fill_in('user[email]', with: 'pedrito-picaso@gmail.com')
    fill_in('Password', with: 'SomeValidPassword01')
    click_button 'Login'

    expect(current_path).to eq(new_user_session_path)
    expect(page).to have_content('Your user has been deactivated. Please contact support@brandcopic.com if you think this has been in error.')
  end

  scenario 'should display a message if the password is not valid' do
    visit new_user_session_path
    fill_in('user[email]', with: 'non-existing-user@gmail.com')
    fill_in('Password', with: 'SomeValidPassword01')
    click_button 'Login'

    expect(current_path).to eq(new_user_session_path)
    expect(page).to have_content('Invalid email or password.')
  end

  scenario 'user can request change the password' do
    user = create(:user, company_id: company.id, email: 'pedrito-picaso@gmail.com',
                         password: 'SomeValidPassword01', password_confirmation: 'SomeValidPassword01',
                         role_id: create(:role, company: company).id,
                         reset_password_token: nil, reset_password_sent_at: nil)

    visit new_user_session_path
    click_link 'Forgot your password?'
    fill_in 'Email', with: user.email
    click_button 'Reset'

    user.reload

    expect(user.reset_password_token).not_to eq(nil)
    expect(user.reset_password_sent_at).not_to eq(nil)
    expect(current_path).to eq(passwords_thanks_path)
    expect(page).to have_content('You will receive an email helping you reset your password in a few minute')
  end

  scenario 'user can change the password using the email reset password instructions' do
    user = build(:user, company_id: company.id, email: 'pedrito-picaso@gmail.com',
                        password: 'SomeValidPassword01', password_confirmation: 'SomeValidPassword01',
                        role_id: create(:role, company: company).id, phone_number: nil, phone_number_verified: false,
                        city: nil, state: nil, street_address: nil, zip_code: nil)
    user.company_users.build(role: create(:role, company: company), company: company, active: true)
    user.save validate: false

    token_raw = user.send_reset_password_instructions

    visit edit_user_password_path(reset_password_token: token_raw)
    fill_in 'New password', with: 'A1234567'
    fill_in 'Repeat new password', with: 'A1234567'
    click_button 'Change'

    expect(current_path).to eq(root_path)
  end
end
