require 'rails_helper'

feature 'Campaign Summary Report Page' do
  let(:company) { create(:company) }
  let(:campaign) { create(:campaign, company: company) }
  let(:user) { create(:user, company: company) }
  let(:company_user) { user.company_users.first }
  let(:place) { create(:place, name: 'A Nice Place', country: 'CR', city: 'Curridabat', state: 'San Jose') }
  let(:permissions) { [] }
  let(:event) { create(:approved_event, campaign: campaign, company: company, place: place) }

  before do
    Warden.test_mode!
    add_permissions permissions
    sign_in user
    campaign
  end

  after do
    Warden.test_reset!
  end

  shared_examples_for 'a user that can view the campaign summary report' do
    before do
      Kpi.create_global_kpis
      campaign.assign_all_global_kpis

      campaign.add_kpi create(:kpi, name: 'Integer field', kpi_type: 'number', capture_mechanism: 'integer')
      campaign.add_kpi create(:kpi, name: 'Decimal field', kpi_type: 'number', capture_mechanism: 'decimal')
      campaign.add_kpi create(:kpi, name: 'Currency field', kpi_type: 'number', capture_mechanism: 'currency')
      campaign.add_kpi create(:kpi, name: 'Radio field', kpi_type: 'count', capture_mechanism: 'radio', kpis_segments: [
        create(:kpis_segment, text: 'Radio Option 1'),
        create(:kpis_segment, text: 'Radio Option 2')
      ])

      campaign.add_kpi create(:kpi, name: 'Checkbox field', kpi_type: 'count', capture_mechanism: 'checkbox', kpis_segments: [
        create(:kpis_segment, text: 'Checkbox Option 1'),
        create(:kpis_segment, text: 'Checkbox Option 2'),
        create(:kpis_segment, text: 'Checkbox Option 3')
      ])

      brand = create(:brand, name: 'Cacique', company_id: company.to_param)
      create(:marque, name: 'Marque #1 for Cacique', brand: brand)
      create(:marque, name: 'Marque #2 for Cacique', brand: brand)
      campaign.brands << brand

      venue = create(:venue,
                     company: company,
                     place: create(:place,
                                   name: 'Bar Los Profesionales', street_number: '198',
                                   route: '3rd Ave', city: 'San José'))
      Sunspot.commit
      company_user.places << venue.place

      # Create some custom fields of different types
      create(:form_field_place,
             name: 'Custom Place', fieldable: campaign, required: false)

      create(:form_field_text,
             name: 'Custom Single Text',
             settings: { 'range_format' => 'characters', 'range_min' => '5', 'range_max' => '20' },
             fieldable: campaign, required: false)

      create(:form_field_text_area,
             name: 'Custom TextArea',
             settings: { 'range_format' => 'words', 'range_min' => '2', 'range_max' => '4' },
             fieldable: campaign, required: false)

      create(:form_field_number,
             name: 'Custom Numeric',
             settings: { 'range_format' => 'value', 'range_min' => '5', 'range_max' => '20' },
             fieldable: campaign, required: false)

      create(:form_field_date,
             name: 'Custom Date', fieldable: campaign, required: false)

      create(:form_field_time,
             name: 'Custom Time', fieldable: campaign, required: false)

      create(:form_field_currency,
             name: 'Custom Currency',
             settings: { 'range_format' => 'digits', 'range_min' => '2', 'range_max' => '4' },
             fieldable: campaign, required: false)

      create(:form_field_calculation,
             name: 'Calculation Sum', operation: '+',
             calculation_label: 'SUM TOTAL',
             options: [
               create(:form_field_option, name: 'Sum Opt1'),
               create(:form_field_option, name: 'Sum Opt2')],
             fieldable: campaign, required: false)

      create(:form_field_calculation,
             name: 'Calculation Subtract', operation: '-',
             calculation_label: 'SUBTRACT TOTAL',
             options: [
               create(:form_field_option, name: 'Subtract Opt1'),
               create(:form_field_option, name: 'Subtract Opt2')],
             fieldable: campaign, required: false)

      create(:form_field_calculation,
             name: 'Calculation Multiply', operation: '*',
             calculation_label: 'MULTIPLY TOTAL',
             options: [
               create(:form_field_option, name: 'Multiply Opt1'),
               create(:form_field_option, name: 'Multiply Opt2')],
             fieldable: campaign, required: false)

      create(:form_field_calculation,
             name: 'Calculation Divide', operation: '/',
             calculation_label: 'DIVIDE TOTAL',
             options: [
               create(:form_field_option, name: 'Divide Opt1'),
               create(:form_field_option, name: 'Divide Opt2')],
             fieldable: campaign, required: false)

      create(:form_field_percentage,
             name: 'Custom Percentage',
             options: [
               create(:form_field_option, name: 'Percentage Opt1', ordering: 1),
               create(:form_field_option, name: 'Percentage Opt2', ordering: 2)],
             fieldable: campaign, required: false)

      create(:form_field_likert_scale,
             name: 'Custom LikertScale',
             options: [
               create(:form_field_option, name: 'LikertScale Opt1'),
               create(:form_field_option, name: 'LikertScale Opt2')],
             statements: [
               create(:form_field_statement, name: 'LikertScale Stat1'),
               create(:form_field_statement, name: 'LikertScale Stat2')],
             fieldable: campaign, required: false)

      create(:form_field_checkbox,
             name: 'Custom Checkbox',
             options: [
               create(:form_field_option, name: 'Checkbox Opt1', ordering: 1),
               create(:form_field_option, name: 'Checkbox Opt2', ordering: 2)],
             fieldable: campaign, required: false)

      create(:form_field_radio,
             name: 'Custom Radio',
             options: [
               create(:form_field_option, name: 'Radio Opt1', ordering: 1),
               create(:form_field_option, name: 'Radio Opt2', ordering: 2)],
             fieldable: campaign, required: false)

      create(:form_field_brand,
             name: 'Brand', fieldable: campaign, required: false)

      create(:form_field_marque,
             name: 'Marque', fieldable: campaign, required: false)
    end

    scenario '# of Events should display the correct number of items for each status in the campaign summary report' do
      create(:approved_event, company: company, campaign: campaign, place: place)
      create(:approved_event, company: company, campaign: campaign, place: place)
      create(:rejected_event, company: company, campaign: campaign, place: place)
      create(:due_event, company: company, campaign: campaign, place: place)
      # Event for another campaign, it should not be in the results
      another_campaign = create(:campaign, company: company)
      company_user.campaigns << another_campaign
      create(:approved_event, company: company, campaign: another_campaign, place: place)

      Sunspot.commit

      visit analysis_campaign_summary_report_path

      select_from_multiselect(campaign.name, from: 'report_campaign_id')
      click_js_link 'Generate'
      wait_for_ajax

      form_results = page.all('.form-results-box .form-result')

      within form_results[0] do
        expect(page).to have_content '# of Events4 TOTAL APPROVED2SUBMITTED0DUE1LATE0REJECTED1'
      end
    end

    scenario 'can see the blank state for campaign KPIs when there are not results' do
      visit analysis_campaign_summary_report_path

      select_from_multiselect(campaign.name, from: 'report_campaign_id')
      click_js_link 'Generate'
      wait_for_ajax

      form_results = page.all('.form-results-box .form-result')

      within form_results[0] do
        expect(page).to have_content '# of Events0 TOTAL APPROVED0SUBMITTED0DUE0LATE0REJECTED0'
      end

      within form_results[1] do
        expect(page).to have_content 'Integer field0 TOTAL APPROVED0SUBMITTED0DUE0LATE0REJECTED0'
      end

      within form_results[2] do
        expect(page).to have_content 'Decimal field0.00 TOTAL APPROVED0.00SUBMITTED0.00DUE0.00LATE0.00REJECTED0.00'
      end

      within form_results[3] do
        expect(page).to have_content 'Currency field$0.00 TOTAL APPROVED$0.00SUBMITTED$0.00DUE$0.00LATE$0.00REJECTED$0.00'
      end

      within form_results[4] do
        expect(page).to have_content 'Samples0 TOTAL APPROVED0SUBMITTED0DUE0LATE0REJECTED0'
      end

      within form_results[5] do
        expect(page).to have_content 'Impressions0 TOTAL APPROVED0SUBMITTED0DUE0LATE0REJECTED0'
      end

      within form_results[6] do
        expect(page).to have_content 'Interactions0 TOTAL APPROVED0SUBMITTED0DUE0LATE0REJECTED0'
      end

      within form_results[7] do
        expect(page).to have_content 'Checkbox field No data collected'
      end

      within form_results[8] do
        expect(page).to have_content 'Gender 0% Male 0% Female'
      end

      within form_results[9] do
        expect(page).to have_content 'Age 0% 0% 0% 0% 0% 0% 0% 0% < 12 12 - 17 18 - 24 25 - 34 35 - 44 45 - 54 55 - 64 65+'
      end

      within form_results[10] do
        expect(page).to have_content 'Ethnicity/Race No data collected'
      end

      within form_results[11] do
        expect(page).to have_content 'Radio field No data collected'
      end
    end
  end

  feature 'admin user', js: true, search: true do
    let(:role) { create(:role, company: company) }

    it_behaves_like 'a user that can view the campaign summary report'
  end

  feature 'non admin user', js: true, search: true do
    let(:role) { create(:non_admin_role, company: company) }

    it_should_behave_like 'a user that can view the campaign summary report' do
      before { company_user.campaigns << campaign }
      before { company_user.places << place }
      let(:permissions) do
        [[:campaign_summary_report, 'Campaign']]
      end
    end
  end

  feature 'filter section', js: true do
    scenario 'should not have decimals for the number field in the campaign summary report' do
      create(:submitted_event, campaign: campaign)

      company_user.campaigns << campaign
      visit analysis_campaign_summary_report_path

      select_from_multiselect(campaign.name, from: 'report_campaign_id')
      click_js_link 'Generate'
      wait_for_ajax

      expect(page).to have_selector('h5', text: 'CAMPAIGN SUMMARY')

      expect(page).to have_selector('div.result_number')
      find_all('.result_number').each do |field|
        ff = field.find('span.form-result-value')
        expect(ff).not_to have_content('.')

        field.find_all('span.form-result-details-row span.value').each do |ff|
          expect(ff).not_to have_content('.')
        end
      end
    end
  end
end
