require 'rails_helper'

describe Analysis::CampaignSummaryReportController, type: :controller do
  let(:user) { sign_in_as_user }
  let(:company) { user.companies.first }
  let(:company_user) { user.current_company_user }
  let(:campaign1) { create(:campaign, company: company, name: 'Test Campaign FY01') }
  let(:campaign2) { create(:campaign, company: company, name: 'CFY12') }
  let(:event1) { create(:submitted_event, campaign: campaign1, company: company) }
  let(:event2) { create(:late_event, campaign: campaign2, company: company) }

  before { user }

  describe "GET 'index'" do
    it 'should return http success' do
      get 'index'
      expect(response).to be_success
    end

    describe 'CSV export' do
      it 'queue the job for export the list to CSV' do
        expect(ListExportWorker).to receive(:perform_async).with(kind_of(Numeric))
        expect do
          xhr :get, :index, format: :csv
        end.to change(ListExport, :count).by(1)
        export = ListExport.last
        expect(export.controller).to eql('Analysis::CampaignSummaryReportController')
        expect(export.export_format).to eql('csv')
      end
    end
  end

  describe "GET 'items'" do
    let(:user1) { create(:company_user, user: create(:user, first_name: 'Roberto', last_name: 'Gomez'), company: company) }
    let(:user2) { create(:company_user, user: create(:user, first_name: 'Mario', last_name: 'Moreno'), company: company) }

    it 'should return correct count of events by Team in People bucket' do
      company_user.campaigns << campaign1
      company_user.campaigns << campaign2

      membership1 = create(:membership, company_user: user.company_users.first, memberable: event1)
      company_user.memberships << membership1
      membership2 = create(:membership, company_user: user.company_users.first, memberable: event2)
      company_user.memberships << membership2

      team = create(:team, name: 'Team 1', company: company)
      team.memberships << membership1

      campaign_ids = "%d, %d" % [campaign1.id, campaign2.id]
      get :items, :campaign_summary => campaign_ids
      expect(response).to be_success
      expect(response.body).to have_selector("span.results-count", :text => "2")

      get :items, :campaign_summary => campaign_ids, :team => [team.id]
      expect(response).to be_success
      expect(response.body).to have_selector("span.results-count", :text => "1")
    end

    it 'should return correct count of events by custom saved filter' do
      event1.users << user1
      event2.users << user2
      Sunspot.commit

      filter = create(:custom_filter,
             owner: company_user, name: 'Custom Filter', apply_to: 'campaign_summary_report',
             filters: 'campaign%5B%5D=' + campaign1.to_param + '&user%5B%5D=' + user1.to_param +
                 '&event_status%5B%5D=Submitted&status%5B%5D=Active')

      # Using Custom Filter
      campaign_ids = "%d, %d" % [campaign1.id, campaign2.id]
      get :items, :campaign_summary => campaign_ids, :cfid => [filter.id]

      expect(response).to be_success
      expect(response.body).to have_selector("span.results-count", :text => "1")
      expect(response.body).to have_content(filter.name)
    end
  end

  describe "GET 'list_export'", :search, :inline_jobs do
    it 'should return an empty book with the correct headers' do
      expect do
        xhr :get, :index, report: { campaign_id: [campaign1.id.to_s], summary_group_by: '' }, format: :csv
      end.to change(ListExport, :count).by(1)
      expect(ListExport.last).to have_rows([
        ['Campaign', 'Event Status']
      ])
    end

    it 'should include the event results for a single campaign' do
      Kpi.create_global_kpis
      campaign1.add_kpi Kpi.impressions
      campaign1.add_kpi Kpi.interactions

      event = create(:approved_event, company: company, campaign: campaign1, start_date: '11/09/2014', end_date: '11/09/2014')
      event.result_for_kpi(Kpi.impressions).value = '15'
      event.result_for_kpi(Kpi.interactions).value = '5'
      event.save

      event = create(:submitted_event, company: company, campaign: campaign1, start_date: '11/10/2014', end_date: '11/10/2014')
      event.result_for_kpi(Kpi.impressions).value = '13'
      event.result_for_kpi(Kpi.interactions).value = '3'
      event.save

      expect do
        xhr :get, :index, report: { campaign_id: [campaign1.id.to_s], summary_group_by: '' }, format: :csv
      end.to change(ListExport, :count).by(1)
      expect(ListExport.last).to have_rows([
        ['Campaign', 'Event Status', 'Impressions', 'Interactions'],
        ['Test Campaign FY01', 'Approved', '15', '5'],
        ['Test Campaign FY01', 'Submitted', '13', '3']
      ])
    end

    it 'should include the event results for a multiples campaigns' do
      Kpi.create_global_kpis
      campaign1.add_kpi Kpi.impressions
      campaign1.add_kpi Kpi.interactions
      campaign1.add_kpi Kpi.samples
      campaign2.add_kpi Kpi.interactions
      campaign2.add_kpi Kpi.samples

      event = create(:approved_event, company: company, campaign: campaign1, start_date: '11/09/2014', end_date: '11/09/2014')
      event.result_for_kpi(Kpi.impressions).value = '15'
      event.result_for_kpi(Kpi.interactions).value = '5'
      event.result_for_kpi(Kpi.samples).value = '25'
      event.save

      event = create(:submitted_event, company: company, campaign: campaign1, start_date: '11/10/2014', end_date: '11/10/2014')
      event.result_for_kpi(Kpi.impressions).value = '13'
      event.result_for_kpi(Kpi.interactions).value = '3'
      event.result_for_kpi(Kpi.samples).value = '23'
      event.save

      event = create(:due_event, company: company, campaign: campaign1)
      event.result_for_kpi(Kpi.interactions).value = '4'
      event.result_for_kpi(Kpi.samples).value = '44'
      event.save

      event = create(:rejected_event, company: company, campaign: campaign2, start_date: '11/09/2014', end_date: '11/09/2014')
      event.result_for_kpi(Kpi.interactions).value = '1'
      event.result_for_kpi(Kpi.samples).value = '11'
      event.save

      event = create(:approved_event, company: company, campaign: campaign2, start_date: '11/10/2014', end_date: '11/10/2014')
      event.result_for_kpi(Kpi.interactions).value = '2'
      event.result_for_kpi(Kpi.samples).value = '22'
      event.save

      event = create(:late_event, company: company, campaign: campaign2)
      event.result_for_kpi(Kpi.interactions).value = '1'
      event.result_for_kpi(Kpi.samples).value = '10'
      event.save

      expect do
        xhr :get, :index, report: { campaign_id: [campaign1.id.to_s, campaign2.id.to_s], summary_group_by: '' }, format: :csv
      end.to change(ListExport, :count).by(1)
      expect(ListExport.last).to have_rows([
        ['Campaign', 'Event Status', 'Interactions', 'Samples', 'Impressions'],
        ['CFY12', 'Rejected', '1', '11'],
        ['CFY12', 'Approved', '2', '22'],
        ['CFY12', 'Late', '1', '10'],
        ['Test Campaign FY01', 'Approved', '5', '25', '15'],
        ['Test Campaign FY01', 'Submitted', '3', '23', '13'],
        ['Test Campaign FY01', 'Due', '4', '44']
      ])
    end
  end
end
