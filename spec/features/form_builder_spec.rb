require 'rails_helper'

RSpec.shared_examples 'a fieldable element' do
  include FormBuilderTestHelpers
  let(:fieldable_path) { url_for(fieldable, only_path: true) }

  scenario 'user can add a field to the form by clicking on it' do
    visit fieldable_path
    expect(page).to have_selector('h2', text: fieldable.name)
    text_field.click
    expect(page).to have_content('Adding new Single line text field at the bottom...')

    expect(form_builder).to have_form_field('Single line text')

    # Save the form
    expect do
      click_js_button 'Save'
      wait_for_ajax
    end.to change(FormField, :count).by(1)
    field = FormField.last
    expect(field.type).to eql 'FormField::Text'
  end

  scenario 'user can add paragraph fields to form' do
    visit fieldable_path
    expect(page).to have_selector('h2', text: fieldable.name)
    page.execute_script 'window.scrollBy(0,500)'
    text_area_field.drag_to form_builder

    expect(form_builder).to have_form_field('Paragraph')

    within form_field_settings_for 'Paragraph' do
      fill_in 'Field label', with: 'My Text Field'

      # Range settings
      fill_in 'Min', with: '10'
      fill_in 'Max', with: '150'
      select_from_chosen 'Words', from: 'Format'

      unicheck 'Required'
    end

    expect(form_builder).to have_form_field('My Text Field')

    # Close the field settings form
    form_builder.trigger 'click'
    expect(page).to have_no_selector('.field-attributes-panel')

    # Save the form
    expect do
      click_js_button 'Save'
      wait_for_ajax
    end.to change(FormField, :count).by(1)
    field = FormField.last
    expect(field.name).to eql 'My Text Field'
    expect(field.type).to eql 'FormField::TextArea'

    within form_field_settings_for 'My Text Field' do
      expect(find_field('Field label').value).to eql 'My Text Field'
      expect(find_field('Min').value).to eql '10'
      expect(find_field('Max').value).to eql '150'
      expect(page).to have_text 'Words'
      expect(find_field('Format', visible: false).value).to eql 'words'
      expect(find_field('Required')['checked']).to be_truthy
    end
  end

  scenario 'user can add single line text fields to form' do
    visit fieldable_path
    expect(page).to have_selector('h2', text: fieldable.name)
    text_field.drag_to form_builder

    expect(form_builder).to have_form_field('Single line text')

    within form_field_settings_for 'Single line text' do
      fill_in 'Field label', with: 'My Text Field'

      # Range settings
      fill_in 'Min', with: '10'
      fill_in 'Max', with: '150'
      select_from_chosen 'Words', from: 'Format'

      unicheck('Required')
    end

    expect(form_builder).to have_form_field('My Text Field')

    # Close the field settings form
    form_builder.trigger 'click'
    expect(page).to have_no_selector('.field-attributes-panel')

    # Save the form
    expect do
      click_js_button 'Save'
      wait_for_ajax
    end.to change(FormField, :count).by(1)
    field = FormField.last
    expect(field.name).to eql 'My Text Field'
    expect(field.required).to be_truthy
    expect(field.type).to eql 'FormField::Text'

    within form_field_settings_for 'My Text Field' do
      expect(find_field('Field label').value).to eql 'My Text Field'
      expect(find_field('Min').value).to eql '10'
      expect(find_field('Max').value).to eql '150'
      expect(page).to have_text 'Words'
      expect(find_field('Format', visible: false).value).to eql 'words'
      expect(find_field('Required')['checked']).to be_truthy
    end
  end

  scenario 'user can add numeric fields to form' do
    visit fieldable_path
    expect(page).to have_selector('h2', text: fieldable.name)
    number_field.drag_to form_builder

    expect(form_builder).to have_form_field('Number')

    within form_field_settings_for 'Number' do
      fill_in 'Field label', with: 'My Numeric Field'

      # Range settings
      fill_in 'Min', with: '10'
      fill_in 'Max', with: '150'
      select_from_chosen 'Value', from: 'Format'

      unicheck('Required')
    end

    expect(form_builder).to have_form_field('My Numeric Field')

    # Close the field settings form
    form_builder.trigger 'click'
    expect(page).to have_no_selector('.field-attributes-panel')

    # Save the form
    expect do
      click_js_button 'Save'
      wait_for_ajax
    end.to change(FormField, :count).by(1)
    field = FormField.last
    expect(field.name).to eql 'My Numeric Field'
    expect(field.type).to eql 'FormField::Number'

    within form_field_settings_for 'My Numeric Field' do
      expect(find_field('Field label').value).to eql 'My Numeric Field'
      expect(find_field('Min').value).to eql '10'
      expect(find_field('Max').value).to eql '150'
      expect(page).to have_text 'Value'
      expect(find_field('Format', visible: false).value).to eql 'value'
      expect(find_field('Required')['checked']).to be_truthy
    end
  end

  scenario 'user can add currency fields to form' do
    visit fieldable_path
    expect(page).to have_selector('h2', text: fieldable.name)
    price_field.drag_to form_builder

    expect(form_builder).to have_form_field('Price')

    within form_field_settings_for 'Price' do
      fill_in 'Field label', with: 'My Price Field'

      # Range settings
      fill_in 'Min', with: '10'
      fill_in 'Max', with: '150'
      select_from_chosen 'Value', from: 'Format'

      unicheck('Required')
    end

    expect(form_builder).to have_form_field('My Price Field')

    # Close the field settings form
    form_builder.trigger 'click'
    expect(page).to have_no_selector('.field-attributes-panel')

    # Save the form
    expect do
      click_js_button 'Save'
      wait_for_ajax
    end.to change(FormField, :count).by(1)
    field = FormField.last
    expect(field.name).to eql 'My Price Field'
    expect(field.type).to eql 'FormField::Currency'

    within form_field_settings_for 'My Price Field' do
      expect(find_field('Field label').value).to eql 'My Price Field'
      expect(find_field('Min').value).to eql '10'
      expect(find_field('Max').value).to eql '150'
      expect(page).to have_text 'Value'
      expect(find_field('Format', visible: false).value).to eql 'value'

      expect(find_field('Required')['checked']).to be_truthy
    end
  end

  scenario 'user can add/delete radio fields to form' do
    visit fieldable_path
    expect(page).to have_selector('h2', text: fieldable.name)
    radio_field.drag_to form_builder

    expect(form_builder).to have_form_field('Multiple Choice',
                                            with_options: ['Option 1']
      )

    within form_field_settings_for 'Multiple Choice' do
      fill_in 'Field label', with: 'My Radio Field'
      fill_in 'option[0][name]', with: 'First Option'
      click_js_link 'Add option after this' # Create another option
      fill_in 'option[1][name]', with: 'Second Option'
    end

    expect(form_builder).to have_form_field('My Radio Field',
                                            with_options: ['First Option', 'Second Option']
      )

    # Close the field settings form
    form_builder.trigger 'click'
    expect(page).to have_no_selector('.field-attributes-panel')

    # Save the form
    expect do
      expect do
        click_js_button 'Save'
        wait_for_ajax
      end.to change(FormField, :count).by(1)
    end.to change(FormFieldOption, :count).by(2)
    field = FormField.last
    expect(field.name).to eql 'My Radio Field'
    expect(field.type).to eql 'FormField::Radio'
    expect(field.options.map(&:name)).to eql ['First Option', 'Second Option']
    expect(field.options.map(&:ordering)).to eql [0, 1]

    # Remove fields
    expect(form_builder).to have_form_field('My Radio Field',
                                            with_options: ['First Option', 'Second Option']
      )

    within form_field_settings_for 'My Radio Field' do
      # Remove the second option (the first one doesn't have the link)
      within('.field-option:nth-child(2)') { click_js_link 'Add option after this' }
      within('.field-option:nth-child(2)') { click_js_link 'Remove this option' }
    end

    confirm_prompt 'Removing this option will remove all the entered data/answers associated with it. '\
                   'Are you sure you want to do this? This cannot be undone'

    within form_field_settings_for 'My Radio Field' do
      expect(page).to have_no_content('Second Option')
    end

    within form_field_settings_for 'My Radio Field' do
      # Remove the second option (the first one doesn't have the link)
      within('.field-option:nth-child(3)') { click_js_link 'Remove this option' }
    end

    confirm_prompt 'Are you sure you want to remove this option?'

    within form_field_settings_for 'My Radio Field' do
      expect(page).to have_no_content('Option 3')
    end

    # Save the form
    expect do
      expect do
        click_js_button 'Save'
        wait_for_ajax
      end.to_not change(FormField, :count)
    end.to change(FormFieldOption, :count).by(-1)
  end

  scenario 'user can add/delete checkbox fields to form' do
    visit fieldable_path
    expect(page).to have_selector('h2', text: fieldable.name)
    checkbox_field.drag_to form_builder

    expect(form_builder).to have_form_field('Checkboxes',
                                            with_options: ['Option 1']
      )

    within form_field_settings_for 'Checkboxes' do
      fill_in 'Field label', with: 'My Checkbox Field'
      fill_in 'option[0][name]', with: 'First Option'
      click_js_link 'Add option after this' # Create another option
      fill_in 'option[1][name]', with: 'Second Option'
    end

    expect(form_builder).to have_form_field('My Checkbox Field',
                                            with_options: ['First Option', 'Second Option']
      )

    # Close the field settings form
    form_builder.trigger 'click'
    expect(page).to have_no_selector('.field-attributes-panel')

    # Save the form
    expect do
      expect do
        click_js_button 'Save'
        wait_for_ajax
      end.to change(FormField, :count).by(1)
    end.to change(FormFieldOption, :count).by(2)
    field = FormField.last
    expect(field.name).to eql 'My Checkbox Field'
    expect(field.type).to eql 'FormField::Checkbox'
    expect(field.options.map(&:name)).to eql ['First Option', 'Second Option']
    expect(field.options.map(&:ordering)).to eql [0, 1]

    # Remove fields
    expect(form_builder).to have_form_field('My Checkbox Field',
                                            with_options: ['First Option', 'Second Option']
      )

    within form_field_settings_for 'My Checkbox Field' do
      # Remove the second option (the first one doesn't have the link)
      within('.field-option:nth-child(2)') { click_js_link 'Add option after this' }
      within('.field-option:nth-child(2)') { click_js_link 'Remove this option' }
    end
    confirm_prompt 'Removing this option will remove all the entered data/answers associated with it. '\
                   'Are you sure you want to do this? This cannot be undone'
    within form_field_settings_for 'My Checkbox Field' do
      expect(page).to have_no_content('Second Option')
    end

    within form_field_settings_for 'My Checkbox Field' do
      within('.field-option:nth-child(3)') { click_js_link 'Remove this option' }
    end

    confirm_prompt 'Are you sure you want to remove this option?'

    within form_field_settings_for 'My Checkbox Field' do
      expect(page).to have_no_content('Option 3')
    end

    # Save the form
    expect do
      expect do
        click_js_button 'Save'
        wait_for_ajax
      end.to_not change(FormField, :count)
    end.to change(FormFieldOption, :count).by(-1)
  end

  scenario 'user can add/delete dropdown fields to form' do
    visit fieldable_path
    expect(page).to have_selector('h2', text: fieldable.name)
    dropdown_field.drag_to form_builder

    expect(form_builder).to have_form_field('Dropdown',
                                            with_options: ['Option 1']
      )

    within form_field_settings_for 'Dropdown' do
      fill_in 'Field label', with: 'My Dropdown Field'
      fill_in 'option[0][name]', with: 'First Option'
      click_js_link 'Add option after this' # Create another option
      fill_in 'option[1][name]', with: 'Second Option'
    end

    expect(form_builder).to have_form_field('My Dropdown Field',
                                            with_options: ['First Option', 'Second Option']
      )

    # Close the field settings form
    form_builder.trigger 'click'
    expect(page).to have_no_selector('.field-attributes-panel')

    # Save the form
    expect do
      expect do
        click_js_button 'Save'
        wait_for_ajax
      end.to change(FormField, :count).by(1)
    end.to change(FormFieldOption, :count).by(2)
    field = FormField.last
    expect(field.name).to eql 'My Dropdown Field'
    expect(field.type).to eql 'FormField::Dropdown'
    expect(field.options.map(&:name)).to eql ['First Option', 'Second Option']
    expect(field.options.map(&:ordering)).to eql [0, 1]

    # Remove fields
    expect(form_builder).to have_form_field('My Dropdown Field',
                                            with_options: ['First Option', 'Second Option']
      )

    within form_field_settings_for 'My Dropdown Field' do
      # Remove the second option (the first one doesn't have the link)
      within('.field-option:nth-child(2)') { click_js_link 'Add option after this' }
      within('.field-option:nth-child(2)') { click_js_link 'Remove this option' }
    end

    confirm_prompt 'Removing this option will remove all the entered data/answers associated with it. '\
                   'Are you sure you want to do this? This cannot be undone'

    within form_field_settings_for 'My Dropdown Field' do
      expect(page).to have_no_content('Second Option')
    end

    within form_field_settings_for 'My Dropdown Field' do
      within('.field-option:nth-child(3)') { click_js_link 'Remove this option' }
    end

    confirm_prompt 'Are you sure you want to remove this option?'

    within form_field_settings_for 'My Dropdown Field' do
      expect(page).to have_no_content('Option 3')
    end
    # Save the form
    expect do
      expect do
        click_js_button 'Save'
        wait_for_ajax
      end.to_not change(FormField, :count)
    end.to change(FormFieldOption, :count).by(-1)
  end

  scenario 'user can add date fields to form' do
    visit fieldable_path
    expect(page).to have_selector('h2', text: fieldable.name)
    date_field.drag_to form_builder

    expect(form_builder).to have_form_field('Date')

    within form_field_settings_for 'Date' do
      fill_in 'Field label', with: 'My Date Field'
      unicheck('Required')
    end

    expect(form_builder).to have_form_field('My Date Field')

    # Close the field settings form
    form_builder.trigger 'click'
    expect(page).to have_no_selector('.field-attributes-panel')

    # Save the form
    expect do
      click_js_button 'Save'
      wait_for_ajax
    end.to change(FormField, :count).by(1)
    field = FormField.last
    expect(field.name).to eql 'My Date Field'
    expect(field.type).to eql 'FormField::Date'

    within form_field_settings_for 'My Date Field' do
      expect(find_field('Field label').value).to eql 'My Date Field'
      expect(find_field('Required')['checked']).to be_truthy
    end
  end

  scenario 'user can add time fields to form' do
    visit fieldable_path
    expect(page).to have_selector('h2', text: fieldable.name)
    time_field.drag_to form_builder

    expect(form_builder).to have_form_field('Time')

    within form_field_settings_for 'Time' do
      fill_in 'Field label', with: 'My Time Field'
      unicheck('Required')
    end

    expect(form_builder).to have_form_field('My Time Field')

    # Close the field settings form
    form_builder.trigger 'click'
    expect(page).to have_no_selector('.field-attributes-panel')

    # Save the form
    expect do
      click_js_button 'Save'
      wait_for_ajax
    end.to change(FormField, :count).by(1)
    field = FormField.last
    expect(field.name).to eql 'My Time Field'
    expect(field.type).to eql 'FormField::Time'

    within form_field_settings_for 'My Time Field' do
      expect(find_field('Field label').value).to eql 'My Time Field'
      expect(find_field('Required')['checked']).to be_truthy
    end
  end

  scenario 'user can add brand fields to form' do
    visit fieldable_path
    expect(page).to have_selector('h2', text: fieldable.name)
    page.execute_script 'window.scrollBy(0,500)'
    brand_field.drag_to form_builder

    expect(form_builder).to have_form_field('Brand')

    within form_field_settings_for 'Brand' do
      unicheck('Required')
    end

    expect(form_builder).to have_form_field('Brand')

    # Close the field settings form
    form_builder.trigger 'click'
    expect(page).to have_no_selector('.field-attributes-panel')

    # Save the form
    expect do
      click_js_button 'Save'
      wait_for_ajax
    end.to change(FormField, :count).by(1)
    field = FormField.last
    expect(field.name).to eql 'Brand'
    expect(field.type).to eql 'FormField::Brand'

    within form_field_settings_for 'Brand' do
      expect(find_field('Required')['checked']).to be_truthy
    end
  end

  scenario 'user can add section fields to form' do
    visit fieldable_path
    expect(page).to have_selector('h2', text: fieldable.name)
    section_field.drag_to form_builder

    expect(form_builder).to have_selector('h3', text: 'Section')

    within form_field_settings_for form_section('Section') do
      fill_in 'Description', with: 'This is the section description'
    end

    # Close the field settings form
    form_builder.trigger 'click'
    expect(page).to have_no_selector('.field-attributes-panel')

    # Save the form
    expect do
      click_js_button 'Save'
      wait_for_ajax
    end.to change(FormField, :count).by(1)
    field = FormField.last
    expect(field.name).to eql 'Section'
    expect(field.settings['description']).to eql 'This is the section description'
    expect(field.type).to eql 'FormField::Section'

    within form_field_settings_for form_section('Section') do
      expect(find_field('Description').value).to eql 'This is the section description'
    end
  end

  scenario 'user can add marque fields to form' do
    visit fieldable_path
    expect(page).to have_selector('h2', text: fieldable.name)
    page.execute_script 'window.scrollBy(0,500)'
    marque_field.drag_to form_builder

    expect(form_builder).to have_form_field('Marque')

    within form_field_settings_for 'Marque' do
      unicheck('Required')
    end

    expect(form_builder).to have_form_field('Marque')

    # Close the field settings form
    form_builder.trigger 'click'
    expect(page).to have_no_selector('.field-attributes-panel')

    # Save the form
    expect do
      click_js_button 'Save'
      wait_for_ajax
    end.to change(FormField, :count).by(1)
    field = FormField.last
    expect(field.name).to eql 'Marque'
    expect(field.type).to eql 'FormField::Marque'

    within form_field_settings_for 'Marque' do
      expect(find_field('Required')['checked']).to be_truthy
    end
  end

  scenario 'user can add photo fields to form' do
    visit fieldable_path
    expect(page).to have_selector('h2', text: fieldable.name)
    photo_field.drag_to form_builder

    expect(form_builder).to have_form_field('Photo')

    within form_field_settings_for 'Photo' do
      fill_in 'Field label', with: 'My Photo Field'
      unicheck('Required')
    end

    expect(form_builder).to have_form_field('My Photo Field')

    # Close the field settings form
    form_builder.trigger 'click'
    expect(page).to have_no_selector('.field-attributes-panel')

    # Save the form
    expect do
      click_js_button 'Save'
      wait_for_ajax
    end.to change(FormField, :count).by(1)
    field = FormField.last
    expect(field.name).to eql 'My Photo Field'
    expect(field.required).to be_truthy
    expect(field.type).to eql 'FormField::Photo'
  end

  scenario 'user can add attachement fields to form' do
    visit fieldable_path
    expect(page).to have_selector('h2', text: fieldable.name)
    attachment_field.drag_to form_builder

    expect(form_builder).to have_form_field('Attachment')

    within form_field_settings_for 'Attachment' do
      fill_in 'Field label', with: 'My Attachment Field'
      unicheck('Required')
    end

    expect(form_builder).to have_form_field('My Attachment Field')

    # Close the field settings form
    form_builder.trigger 'click'
    expect(page).to have_no_selector('.field-attributes-panel')

    # Save the form
    expect do
      click_js_button 'Save'
      wait_for_ajax
    end.to change(FormField, :count).by(1)
    field = FormField.last
    expect(field.name).to eql 'My Attachment Field'
    expect(field.required).to be_truthy
    expect(field.type).to eql 'FormField::Attachment'
  end

  scenario 'user can add/delete percentage fields to form' do
    visit fieldable_path
    expect(page).to have_selector('h2', text: fieldable.name)
    percentage_field.drag_to form_builder

    expect(form_builder).to have_form_field('Percent',
                                            with_options: ['Option 1', 'Option 2', 'Option 3']
      )

    within form_field_settings_for 'Percent' do
      fill_in 'Field label', with: 'My Percent Field'
      fill_in 'option[0][name]', with: 'First Option'
      within('.field-option:nth-child(2)') { click_js_link 'Add option after this' } # Create another option
      fill_in 'option[1][name]', with: 'Second Option'
    end

    expect(form_builder).to have_form_field('My Percent Field',
                                            with_options: ['First Option', 'Second Option']
      )

    # Close the field settings form
    form_builder.trigger 'click'
    expect(page).to have_no_selector('.field-attributes-panel')

    # Save the form
    expect do
      expect do
        click_js_button 'Save'
        wait_for_ajax
      end.to change(FormField, :count).by(1)
    end.to change(FormFieldOption, :count).by(4)
    field = FormField.last
    expect(field.name).to eql 'My Percent Field'
    expect(field.type).to eql 'FormField::Percentage'
    expect(field.options.map(&:name)).to eql ['First Option', 'Second Option', 'Option 2', 'Option 3']
    expect(field.options.map(&:ordering)).to eql [0, 1, 2, 3]

    # Remove fields
    expect(form_builder).to have_form_field('My Percent Field',
                                            with_options: ['First Option', 'Second Option']
    )

    within form_field_settings_for 'My Percent Field' do
      # Remove the second option (the first one doesn't have the link)
      within('.field-option:nth-child(2)') { click_js_link 'Add option after this' }
      within('.field-option:nth-child(2)') { click_js_link 'Remove this option' }
    end
    confirm_prompt 'Removing this option will remove all the entered data/answers associated with it.'\
                   ' Are you sure you want to do this? This cannot be undone'

    within form_field_settings_for 'My Percent Field' do
      expect(page).to have_no_content('Second Option')
      within('.field-option:nth-child(3)') { click_js_link 'Remove this option' }
    end

    confirm_prompt 'Are you sure you want to remove this option?'

    within form_field_settings_for 'My Percent Field' do
      expect(page).to have_no_content('Option 3')
    end

    # Save the form
    expect do
      expect do
        click_js_button 'Save'
        wait_for_ajax
      end.to_not change(FormField, :count)
    end.to change(FormFieldOption, :count).by(-1)
  end

  scenario 'user can add/delete calculation fields to form' do
    visit fieldable_path
    expect(page).to have_selector('h2', text: fieldable.name)
    calculation_field.drag_to form_builder

    expect(form_builder).to have_form_field('Calculation',
                                            with_options: ['Option 1', 'Option 2'])

    within form_field_settings_for 'Calculation' do
      fill_in 'Field label', with: 'My Calculation Field'
      fill_in 'option[0][name]', with: 'First Option'
      within('.field-option:nth-child(2)') { click_js_link 'Add option after this' } # Create another option

      fill_in 'option[1][name]', with: 'Second Option'
    end

    expect(form_builder).to have_form_field('My Calculation Field',
                                            with_options: ['First Option', 'Second Option'])

    # Close the field settings form
    form_builder.trigger 'click'
    expect(page).to have_no_selector('.field-attributes-panel')

    # Save the form
    expect do
      expect do
        click_js_button 'Save'
        wait_for_ajax
      end.to change(FormField, :count).by(1)
    end.to change(FormFieldOption, :count).by(3)
    field = FormField.last
    expect(field.name).to eql 'My Calculation Field'
    expect(field.type).to eql 'FormField::Calculation'
    expect(field.settings['operation']).to eql '+'
    expect(field.settings['calculation_label']).to eql 'TOTAL'
    expect(field.options.map(&:name)).to eql ['First Option', 'Second Option', 'Option 2']
    expect(field.options.map(&:ordering)).to eql [0, 1, 2]

    within form_field_settings_for 'My Calculation Field' do
      find('a[data-operation="*"]').click
      confirm_prompt 'Are you sure you want to change the operation from Add to Multiply? '\
                     'Doing so will cause all previously saved data to be recalculated.'
    end
    click_js_button 'Save'
    wait_for_ajax
    field.reload
    expect(field.settings['operation']).to eql '*'

    # Edit option label
    within form_field_settings_for 'My Calculation Field' do
      fill_in 'option[0][name]', with: 'other name'
      confirm_prompt 'Are you sure you want to change this item from "First Option" to "other name"? '\
                     'Doing so will change this everywhere in the system including reports '\
                     'and may result in inaccurately labeled data.'
    end

    # Remove fields
    expect(form_builder).to have_form_field('My Calculation Field',
                                            with_options: ['other name', 'Second Option']
    )

    within form_field_settings_for 'My Calculation Field' do
      # Remove the second option (the first one doesn't have the link)
      within('.field-option:nth-child(2)') { click_js_link 'Add option after this' }
      within('.field-option:nth-child(2)') { click_js_link 'Remove this option' }
    end

    confirm_prompt 'Removing this option will remove all the entered data/answers associated with it. '\
                   'Are you sure you want to do this? This cannot be undone'

    within form_field_settings_for 'My Calculation Field' do
      expect(page).to have_no_content('Second Option')
    end

    within form_field_settings_for 'My Calculation Field' do
      within('.field-option:nth-child(3)') { click_js_link 'Remove this option' }
    end

    confirm_prompt 'Are you sure you want to remove this option?'
    within form_field_settings_for 'My Calculation Field' do
      expect(page).to have_no_content('Option 3')
    end

    # Save the form
    expect do
      expect do
        click_js_button 'Save'
        wait_for_ajax
      end.to_not change(FormField, :count)
    end.to change(FormFieldOption, :count).by(-1)
  end

  scenario 'user can add/modify/delete likert scale fields to form' do
    visit fieldable_path
    expect(page).to have_selector('h2', text: fieldable.name)
    likert_scale_field.drag_to form_builder

    expect(form_builder).to have_form_field('Likert scale',
                                            with_options: ['Strongly Disagree', 'Disagree',
                                                           'Agree', 'Strongly Agree'])

    within form_field_settings_for 'Likert scale' do
      fill_in 'Field label', with: 'My Likert scale Field'

      within '.field-options[data-type="statement"]' do
        fill_in 'statement[0][name]', with: 'First Statement'
        within('.field-option', match: :first) { click_js_link 'Add option after this' } # Create another option
        fill_in 'statement[1][name]', with: 'Second Statement'
      end

      within '.field-options[data-type="option"]' do
        fill_in 'option[0][name]', with: 'First Option'
        within('.field-option', match: :first) { click_js_link 'Add option after this' } # Create another option
        fill_in 'option[1][name]', with: 'Second Option'
      end
    end

    expect(form_builder).to have_form_field('My Likert scale Field',
                                            with_options: ['First Option', 'Second Option']
      )

    # Close the field settings form
    form_builder.trigger 'click'
    expect(page).to have_no_selector('.field-attributes-panel')

    # Save the form
    expect do
      expect do
        click_js_button 'Save'
        wait_for_ajax
      end.to change(FormField, :count).by(1)
    end.to change(FormFieldOption, :count).by(9)
    field = FormField.last
    expect(field.name).to eql 'My Likert scale Field'
    expect(field.type).to eql 'FormField::LikertScale'
    expect(field.multiple).to eql false
    expect(field.options.order('ordering ASC').map(&:name)).to eql [
      'First Option', 'Second Option', 'Disagree', 'Agree', 'Strongly Agree']
    expect(field.options.map(&:ordering)).to eql [0, 1, 2, 3, 4]
    expect(field.statements.map(&:name)).to eql ['First Statement', 'Second Statement',
                                                 'Statement 2', 'Statement 3']
    expect(field.statements.map(&:ordering)).to eql [0, 1, 2, 3]

    expect(form_builder).to have_form_field('My Likert scale Field',
                                            with_options: ['First Option', 'Second Option', 'Disagree',
                                                           'Agree', 'Strongly Agree']
    )

    within '.form_field_likertscale' do
      expect(page).to have_selector('label.radio')
      expect(page).to have_no_selector('label.checkbox.multiple')
    end

    # Multiple Answers / Checkboxes
    within form_field_settings_for 'My Likert scale Field' do
      unicheck('Allow multiple answers per statement')
    end

    # Close the field settings form
    form_builder.trigger 'click'

    click_js_button 'Save'
    wait_for_ajax

    field = FormField.last
    expect(field.multiple).to eql true

    within '.form_field_likertscale' do
      expect(page).to have_no_selector('label.radio')
      expect(page).to have_selector('label.checkbox.multiple')
    end

    # Creating results for field
    if fieldable.is_a?(Campaign)
      event = create(:approved_event, campaign_id: fieldable.id,
                                      place: create(:place),
                                      start_date: '01/23/2013',
                                      end_date: '01/23/2013')

      event.results_for([field]).first.value = { field.statements.first.id.to_s => field.options.first.id.to_s }
      expect(event.save).to be_truthy
    elsif fieldable.is_a?(ActivityType)
      campaign = create(:campaign, company: fieldable.company)
      campaign.activity_types << fieldable
      event = create(:approved_event, campaign: campaign,
                                      place: create(:place),
                                      start_date: '01/23/2013',
                                      end_date: '01/23/2013')
      activity = create(:activity, activity_type: fieldable, activitable: event,
                                   company_user: create(:company_user, company: fieldable.company))
      activity.results_for([field]).first.value = { field.statements.first.id.to_s => field.options.first.id.to_s }
      expect(activity.save).to be_truthy
    end

    # Reload page to refresh field object data (have_results)
    visit fieldable_path

    # Should not display the multiple answers option for fields with results
    within form_field_settings_for 'My Likert scale Field' do
      expect(page).to_not have_text('Allow multiple answers per statement')
    end

    # Remove fields
    within form_field_settings_for 'My Likert scale Field' do
      # Remove the second option (the first one doesn't have the link)
      within('.field-options[data-type="option"] .field-option:nth-child(2)') do
        click_js_link 'Add option after this'
      end
      within('.field-options[data-type="option"] .field-option:nth-child(4)') do
        click_js_link 'Remove this option'
      end
    end

    confirm_prompt 'Removing this option will remove all the entered data/answers associated with it. '
    'Are you sure you want to do this? This cannot be undone'

    within form_field_settings_for 'My Likert scale Field' do
      within('.field-options[data-type="option"]') { expect(page).to have_no_content('Second Option') }
    end
    within form_field_settings_for 'My Likert scale Field' do
      within('.field-options[data-type="option"] .field-option:nth-child(3)') { click_js_link 'Remove this option' }
    end

    confirm_prompt 'Are you sure you want to remove this option?'

    within form_field_settings_for 'My Likert scale Field' do
      expect(page).to have_no_content('Option 3')
    end

    within form_field_settings_for 'My Likert scale Field' do
      # Remove the second statement (the first one doesn't have the link)
      within('.field-options[data-type="statement"] .field-option:nth-child(2)') do
        click_js_link 'Add option after this'
      end
      within('.field-options[data-type="statement"] .field-option:nth-child(4)') do
        click_js_link 'Remove this option'
      end
    end
    confirm_prompt 'Removing this statement will remove all the entered data/answers associated with it. '
    'Are you sure you want to do this? This cannot be undone'
    within form_field_settings_for 'My Likert scale Field' do
      within('.field-options[data-type="statement"]') { expect(page).to have_no_content('Second Option') }
    end
    within form_field_settings_for 'My Likert scale Field' do
      within('.field-options[data-type="statement"] .field-option:nth-child(3)') do
        click_js_link 'Remove this option'
      end
    end
    confirm_prompt 'Are you sure you want to remove this statement?'
    within form_field_settings_for 'My Likert scale Field' do
      expect(page).to have_no_content('Statement 3')
    end

    # Save the form
    expect do
      expect do
        click_js_button 'Save'
        wait_for_ajax
      end.to_not change(FormField, :count)
    end.to change(FormFieldOption, :count).by(-2)
  end

  scenario 'user can remove a field from the form that was just added' do
    visit fieldable_path
    expect(page).to have_selector('h2', text: fieldable.name)
    text_field.drag_to form_builder

    expect(form_builder).to have_form_field('Single line text')

    form_field_settings_for 'Single line text'
    within form_builder.find('.field.selected') do
      click_js_link 'Remove'
    end

    confirm_prompt 'Are you sure you want to remove this field?'

    expect(form_builder).to_not have_form_field('Single line text')

    # Save the form, should not create any field
    expect do
      click_js_button 'Save'
      wait_for_ajax
    end.to_not change(FormField, :count)
  end

  scenario 'user can remove an existing field from the form' do
    visit fieldable_path
    expect(page).to have_selector('h2', text: fieldable.name)
    text_field.drag_to form_builder

    expect(form_builder).to have_form_field('Single line text')
    # Save the form
    expect do
      click_js_button 'Save'
      wait_for_ajax
    end.to change(FormField, :count).by(1)

    visit fieldable_path

    expect(form_builder).to have_form_field('Single line text')

    form_field_settings_for 'Single line text'
    within form_builder.find('.field.selected') do
      click_js_link 'Remove'
    end

    confirm_prompt 'Removing this field will remove all the entered data/answers associated with it. '\
                   'Are you sure you want to do this?'

    expect(form_builder).to_not have_form_field('Single line text')

    # Save the form, should not create any field
    expect do
      click_js_button 'Save'
      wait_for_ajax
    end.to change(FormField, :count).by(-1)
  end
end

RSpec.shared_examples 'a fieldable element that accept kpis' do
  include FormBuilderTestHelpers
  let(:fieldable_path) { url_for(fieldable, only_path: true) }

  let(:kpi) do
    create(:kpi, name: 'My Custom KPI',
    description: 'my custom kpi description',
    kpi_type: 'number', capture_mechanism: 'integer', company: fieldable.company)
  end

  scenario 'add a global KPIs to the form' do
    Kpi.create_global_kpis
    visit fieldable_path
    expect(page).to have_selector('h2', text: fieldable.name)
    toggle_collapsible 'KPIs'
    toggle_collapsible 'Fields' # Hide fields

    # Wait for accordeon effect to complete
    within('.fields-wrapper') do
      expect(page).to have_no_content('Dropdown')
    end

    within('.fields-wrapper') do
      expect(page).to have_content('Impressions')
      expect(page).to have_content('Interactions')
      expect(page).to have_content('Samples')
      expect(page).to have_content('Age')
      expect(page).to have_content('Gender')
      expect(page).to have_content('Ethnicity/Race')
    end

    kpi_field(Kpi.impressions).drag_to form_builder
    kpi_field(Kpi.interactions).drag_to form_builder
    kpi_field(Kpi.age).drag_to form_builder
    kpi_field(Kpi.gender).drag_to form_builder
    kpi_field(Kpi.ethnicity).drag_to form_builder
    kpi_field(Kpi.samples).drag_to form_builder

    # Make sure the KPIs are not longer available in the KPIs list
    within('.fields-wrapper') do
      expect(page).to have_no_content('Impressions')
      expect(page).to have_no_content('Interactions')
      expect(page).to have_no_content('Samples')
      expect(page).to have_no_content('Age')
      expect(page).to have_no_content('Gender')
      expect(page).to have_no_content('Ethnicity/Race')
    end

    within form_field_settings_for 'Impressions' do
      fill_in 'Field label', with: 'Impressions Custom Name'
      unicheck('Required')
    end

    expect(form_builder).to have_form_field('Impressions Custom Name')

    # Close the field settings form
    form_builder.trigger 'click'
    expect(page).to have_no_selector('.field-attributes-panel')

    # Save the form
    expect do
      click_js_button 'Save'
      wait_for_ajax
    end.to change(FormField, :count).by(6)
    field = fieldable.form_fields.where(kpi_id: Kpi.impressions).first
    expect(field.name).to eql 'Impressions Custom Name'
    expect(field.type).to eql 'FormField::Number'
    expect(field.kpi_id).to eql field.kpi_id

    within form_field_settings_for 'Impressions Custom Name' do
      expect(find_field('Field label').value).to eql 'Impressions Custom Name'
      expect(find_field('Required')['checked']).to be_truthy
    end

    # Remove the impressions KPI form the form
    form_field_settings_for 'Impressions Custom Name'
    within form_builder.find('.field.selected') do
      click_js_link 'Remove'
    end

    confirm_prompt 'Removing this field will remove all the entered data/answers associated with it. '\
                   'Are you sure you want to do this?'

    # Make sure the KPI is again available in the KPIs list
    within('.fields-wrapper') do
      expect(page).to have_content('Impressions')
    end
  end

  scenario 'add a kpi to the form' do
    kpi.save
    visit fieldable_path
    expect(page).to have_selector('h2', text: fieldable.name)
    toggle_collapsible 'KPIs'
    toggle_collapsible 'Fields' # Hide fields

    # Wait for accordeon effect to complate
    within('.fields-wrapper') do
      expect(page).to have_no_content('Dropdown')
    end

    kpi_field(kpi).drag_to form_builder

    # Make sure the KPI is not longer available in the KPIs list
    within('.fields-wrapper') do
      expect(page).to have_no_content('My Custom KPI')
    end

    within form_field_settings_for 'My Custom KPI' do
      fill_in 'Field label', with: 'My Custom KPI custom name'
      unicheck('Required')
    end

    expect(form_builder).to have_form_field('My Custom KPI')

    # Close the field settings form
    form_builder.trigger 'click'
    expect(page).to have_no_selector('.field-attributes-panel')

    # Save the form
    expect do
      click_js_button 'Save'
      wait_for_ajax
    end.to change(FormField, :count).by(1)
    field = FormField.last
    expect(field.name).to eql 'My Custom KPI custom name'
    expect(field.type).to eql 'FormField::Number'
    expect(field.kpi_id).to eql field.kpi_id

    within form_field_settings_for 'My Custom KPI custom name' do
      expect(find_field('Field label').value).to eql 'My Custom KPI custom name'
      expect(find_field('Required')['checked']).to be_truthy
    end

    # Remove the KPI form the form
    form_field_settings_for 'My Custom KPI custom name'
    within form_builder.find('.field.selected') do
      click_js_link 'Remove'
    end

    confirm_prompt 'Removing this field will remove all the entered data/answers associated with it. '\
                   'Are you sure you want to do this?'

    # Make sure the KPI is again available in the KPIs list
    within('.fields-wrapper') do
      expect(page).to have_content('My Custom KPI')
    end
  end

  scenario "disable KPI's segments in form builder" do
    kpi =  create(:kpi, name: 'My Custom KPI',
                        description: 'my custom kpi description',
                        kpi_type: 'count', capture_mechanism: 'dropdown', company: fieldable.company,
                        kpis_segments: [
                          segment1 = create(:kpis_segment, text: 'Option1'),
                          segment2 = create(:kpis_segment, text: 'Option2')])

    visit fieldable_path

    expect(page).to have_selector('h2', text: fieldable.name)
    toggle_collapsible 'KPIs'
    toggle_collapsible 'Fields' # Hide fields

    # Wait for accordeon effect to complate
    within('.fields-wrapper') do
      expect(page).to have_no_content('Dropdown')
    end

    kpi_field(kpi).drag_to form_builder

    expect(form_builder).to have_form_field('My Custom KPI', options: %w(Option1 Option2))

    within form_field_settings_for 'My Custom KPI' do
      within find('.field-option', match: :first) do
        expect(find('input[type="text"]').value).to eql 'Option1'
        click_js_link 'Deactivate this option'
        confirm_prompt 'Are you sure you want to disable the option "Option1" for this KPI?'
        expect(page).to have_link('Activate this option')
      end
    end

    expect(form_builder).to have_form_field('My Custom KPI', options: ['Option2'])

    # Close the field settings form
    form_builder.trigger 'click'
    expect(page).to have_no_selector('.field-attributes-panel')

    # Save the form
    expect do
      click_js_button 'Save'
      wait_for_ajax
    end.to change(FormField, :count).by(1)
    field = FormField.last
    expect(field.name).to eql 'My Custom KPI'
    expect(field.type).to eql 'FormField::Dropdown'
    expect(field.kpi_id).to eql field.kpi_id
    expect(field.settings['disabled_segments']).to eql [segment1.id.to_s]

    within form_field_settings_for 'My Custom KPI' do
      expect(find_field('Field label').value).to eql 'My Custom KPI'
      within find('.field-option', match: :first) do
        expect(find('input[type="text"]').value).to eql 'Option1'
        expect(page).to have_link('Activate this option')
      end
    end
  end
end

RSpec.shared_examples 'a fieldable element that accept modules' do
  include FormBuilderTestHelpers
  let(:fieldable_path) { url_for(fieldable, only_path: true) }

  scenario 'add/remove a module to the form' do

    visit fieldable_path
    expect(page).to have_selector('h2', text: fieldable.name)
    toggle_collapsible 'Modules'
    toggle_collapsible 'Fields' # Hide fields

    # Wait for accordeon effect to complate
    within('.fields-wrapper') do
      expect(page).to have_no_content('Dropdown')
    end

    module_field('Gallery').drag_to form_builder

    # Make sure the KPI is not longer available in the KPIs list
    within('.fields-wrapper') do
      expect(page).to have_no_content('Media Gallery')
    end

    expect(find('.form-wrapper')).to have_selector('.form-section.module[data-type=Photos]')

    within form_field_settings_for(module_section('Media Gallery')) do
      fill_in 'Min', with: '10'
      fill_in 'Max', with: '150'
    end

    # Save the form
    click_js_button 'Save'
    wait_for_ajax
    expect(fieldable.reload.enabled_modules).to include('photos')

    visit fieldable_path

    within form_field_settings_for(module_section('Media Gallery')) do
      expect(find_field('Min').value).to eql '10'
      expect(find_field('Max').value).to eql '150'
    end

    within module_section('Media Gallery') do
      click_js_link 'Remove'
    end

    confirm_prompt 'Removing this module will remove all the entered data associated with it. '
    'Are you sure you want to do this?'

    expect(find('.form-wrapper')).to have_no_selector('.form-section.module[data-type=Photos]')
    click_js_button 'Save'
    wait_for_ajax

    # open the Modules fields list
    toggle_collapsible 'Modules'
    toggle_collapsible 'Fields' # Hide fields

    # Wait for accordeon effect to complete
    within('.fields-wrapper') do
      expect(page).to have_no_content('Dropdown')
    end

    # The changes were applied in the database
    expect(fieldable.reload.enabled_modules).to be_empty

    # the module should be available again in the list of modules
    expect(find('.fields-wrapper')).to have_content('Media Gallery')

    expect(find('.form-wrapper')).to have_no_selector('.form-section.module[data-type=Photos]')
    # the module should be available again in the list of modules
    expect(find('.fields-wrapper')).to have_content('Media Gallery')
  end

  scenario 'add and configure an Attendance module' do
    company.update_attribute(:kbmg_enabled, 'true')
    visit fieldable_path
    expect(page).to have_selector('h2', text: fieldable.name)
    toggle_collapsible 'Modules'
    toggle_collapsible 'Fields' # Hide fields

    # Wait for accordeon effect to complate
    within('.fields-wrapper') do
      expect(page).to have_no_content('Dropdown')
    end

    module_field('Attendance').drag_to form_builder

    within('.fields-wrapper') do
      expect(page).to have_no_content('Attendance')
    end

    expect(find('.form-wrapper')).to have_selector('.form-section.module[data-type=Attendance]')

    within form_field_settings_for(module_section('Attendance')) do
      fill_in 'KBMG API Key', with: 'SOME-API-TOKEN'
    end

    click_js_button 'Save'
    wait_for_ajax
    expect(fieldable.reload.enabled_modules).to include('attendance')

    visit fieldable_path

    within form_field_settings_for(module_section('Attendance')) do
      expect(find_field('KBMG API Key').value).to eql 'SOME-API-TOKEN'
    end
  end
end

feature 'Campaign Form Builder', js: true do
  include FormBuilderTestHelpers
  before { Company.destroy_all }

  let(:user) { create(:user, company_id: company.id, role_id: create(:role).id) }

  let(:company) {  create(:company) }

  before { sign_in user }

  it_behaves_like 'a fieldable element' do
    let(:fieldable) { create(:campaign, company: company) }
    let(:fieldable_path) { campaign_path(fieldable) }
  end

  it_behaves_like 'a fieldable element that accept kpis' do
    let(:fieldable) { create(:campaign, company: company) }
    let(:fieldable_path) { campaign_path(fieldable) }
  end

  it_behaves_like 'a fieldable element that accept modules' do
    let(:company) { create(:company, id: 2) }
    let(:fieldable) { create(:campaign, company: company) }
    let(:fieldable_path) { campaign_path(fieldable) }
  end

  context 'form builder and KPI list integration' do
    let(:campaign) { create(:campaign, company: company) }

    scenario 'adding a KPI from the list' do
      kpi = create(:kpi, name: 'My Custom KPI', company_id: company.id)
      visit campaign_path(campaign)

      # The kpi is in the list of KPIs in the sidebar
      toggle_collapsible 'KPIs'
      toggle_collapsible 'Fields' # Hide fields

      within('.fields-wrapper') do
        expect(page).to have_no_content('Dropdown')  # Wait for accordeon effect to complete
        expect(page).to have_content('My Custom KPI')
      end

      open_tab 'KPIs'
      click_js_link 'Add KPI'
      within visible_modal do
        fill_in 'Search', with: 'custom'
        expect(page).to have_content 'My Custom KPI'

        within(resource_item kpi) { click_js_link 'Add KPI' }
        expect(page).to have_no_content 'My Custom KPI'
      end
      close_modal

      # Test the field is in the form builder and the KPI
      # was removed from KPIs list in the sidebar
      open_tab 'Post Event form'
      expect(form_builder).to have_form_field 'My Custom KPI'

      within('.fields-wrapper') do
        expect(page).to have_no_content('My Custom KPI')
      end

      # reload page and test the field is still there...
      visit campaign_path(campaign)
      expect(form_builder).to have_form_field 'My Custom KPI'
      toggle_collapsible 'KPIs'
      toggle_collapsible 'Fields' # Hide fields

      within('.fields-wrapper') do
        expect(page).to have_no_content('Dropdown')  # Wait for accordeon effect to complete
        expect(page).to have_no_content('My Custom KPI')
      end

      # Now test the removal of the KPI from the list
      open_tab 'KPIs'

      within resource_item 1, list: '.kpis-list' do
        expect(page).to have_content 'My Custom KPI'
        click_js_link 'Remove'
      end

      confirm_prompt 'Please confirm you want to remove this KPI?'
      within '.kpis-list' do
        expect(page).to have_no_content 'My Custom KPI'
      end

      open_tab 'Post Event form'

      expect(form_builder).to_not have_form_field 'My Custom KPI'

      # The KPI should be again available in the KPIs list
      toggle_collapsible 'KPIs'
      within('.fields-wrapper') do
        expect(page).to have_content('My Custom KPI')
      end
    end
  end
end

RSpec.shared_examples 'a fieldable element that accepts Place fields' do
  include FormBuilderTestHelpers
  scenario 'user can add Place fields to form' do
    visit fieldable_path
    expect(page).to have_selector('h2', text: fieldable.name)
    place_field.drag_to form_builder

    expect(form_builder).to have_form_field('Place')

    within form_field_settings_for 'Place' do
      fill_in 'Field label', with: 'My Place Field'

      unicheck('Required')
    end

    expect(form_builder).to have_form_field('My Place Field')

    # Close the field settings form
    form_builder.trigger 'click'
    expect(page).to have_no_selector('.field-attributes-panel')

    # Save the form
    expect do
      click_js_button 'Save'
      wait_for_ajax
    end.to change(FormField, :count).by(1)
    field = FormField.last
    expect(field.name).to eql 'My Place Field'
    expect(field.required).to be_truthy
    expect(field.type).to eql 'FormField::Place'

    within form_field_settings_for 'My Place Field' do
      expect(find_field('Field label').value).to eql 'My Place Field'
      expect(find_field('Required')['checked']).to be_truthy
    end
  end
end

feature 'Activity Types', js: true do
  let(:user) { create(:user, company_id: create(:company).id, role_id: create(:role).id) }

  let(:company) { user.companies.first }

  before { sign_in user }

  it_behaves_like 'a fieldable element' do
    let(:fieldable) { create(:activity_type, name: 'Drink Menu', company: company) }
    let(:fieldable_path) { activity_type_path(fieldable) }
  end

  it_behaves_like 'a fieldable element that accepts Place fields' do
    let(:fieldable) { create(:activity_type, name: 'Drink Menu', company: company) }
    let(:fieldable_path) { activity_type_path(fieldable) }
  end
end
