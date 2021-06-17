# == Schema Information
#
# Table name: reports
#
#  id            :integer          not null, primary key
#  company_id    :integer
#  name          :string(255)
#  description   :text
#  active        :boolean          default("true")
#  created_by_id :integer
#  updated_by_id :integer
#  rows          :text
#  columns       :text
#  values        :text
#  filters       :text
#  sharing       :string(255)      default("owner")
#

require 'rails_helper'

describe Report, type: :model do
  it { is_expected.to validate_presence_of(:name) }

  describe '#activate' do
    let(:report) { build(:report, active: false) }

    it 'should return the active value as true' do
      report.activate!
      report.reload
      expect(report.active).to be_truthy
    end
  end

  describe '#deactivate' do
    let(:report) { build(:report, active: false) }

    it 'should return the active value as false' do
      report.deactivate!
      report.reload
      expect(report.active).to be_falsey
    end
  end

  describe '#accessible_by_user' do
    let(:user) { create(:company_user, company: company) }
    let(:company) { create(:company)  }
    before { User.current = user.user }
    it 'should return all the reports created by the current user' do
      report = create(:report, company: company)
      expect(described_class.accessible_by_user(user)).to match_array [report]
    end

    it 'should return all the reports shared with everyone by the current user' do
      report = create(:report, company: company, sharing: 'everyone')
      other_user = create(:company_user, company: company)
      expect(described_class.accessible_by_user(user)).to match_array [report]
      expect(described_class.accessible_by_user(other_user)).to match_array [report]

      # Should not return reports from other company
      other_company_user = create(:company_user, company: create(:company))
      expect(described_class.accessible_by_user(other_company_user)).to match_array []
    end

    it "should return reports shared with the user's role" do
      report = create(:report, company: company,
        sharing: 'custom', sharing_selections: ["role:#{user.role_id}"])
      other_user = create(:company_user, company: company, role: user.role)
      expect(described_class.accessible_by_user(user)).to match_array [report]
      expect(described_class.accessible_by_user(other_user)).to match_array [report]
    end

    it "should return reports shared with the user's role" do
      other_user = create(:company_user, company: company, role: user.role)
      team = create(:team, company: company)
      team.users << user
      team.users << other_user
      report = create(:report, company: company,
        sharing: 'custom', sharing_selections: ["team:#{team.id}", 'company_user:9999999', 'role:9999999'])
      report2 = create(:report, company: company)
      create(:company_user, company: create(:company))
      expect(described_class.accessible_by_user(user)).to match_array [report, report2]
      expect(described_class.accessible_by_user(other_user)).to match_array [report]
    end

    it 'should return reports shared with the user' do
      other_report = create(:report, company: company, sharing: 'owner')
      other_report.update_attribute(:created_by_id, user.id + 100)
      other_user = create(:company_user, company: company, role: user.role)
      team = create(:team, company: company)
      team.users << user
      team.users << other_user
      report = create(:report, company: company,
        sharing: 'custom', sharing_selections: ["company_user:#{other_user.id}"])
      expect(described_class.accessible_by_user(user)).to match_array [report]
      expect(described_class.accessible_by_user(other_user)).to match_array [report]
    end
  end

  describe '#format_values' do
    let(:company) { create(:company) }

    it "should correcly apply the 'display' formula to values" do
      campaign1 = create(:campaign, company: company, name: 'Campaign 1')
      campaign2 = create(:campaign, company: company, name: 'Campaign 2')
      create(:event, campaign: campaign1,
                     place: create(:place, name: 'Bar 1', state: 'State 1'),
                     results: { impressions: 300, interactions: 20, samples: 10 })

      create(:event, campaign: campaign1,
                     place: create(:place, name: 'Bar 2', state: 'State 2'),
                     results: { impressions: 700, interactions: 40, samples: 10 })

      create(:event, campaign: campaign2,
                     place: create(:place, name: 'Bar 3', state: 'State 1'),
                     results: { impressions: 200, interactions: 80, samples: 40 })

      create(:event, campaign: campaign2,
                     place: create(:place, name: 'Bar 4', state: 'State 2'),
                     results: { impressions: 100, interactions: 60, samples: 60 })

      report = create(:report,
                      company: company,
                      columns: [{ 'field' => 'values', 'label' => 'Values' },
                                { 'field' => 'place:state', 'label' => 'State' }],
                      rows:    [{ 'field' => 'campaign:name', 'label' => 'Campaign Name' }],
                      values:  [
                        { 'field' => "kpi:#{Kpi.impressions.id}", 'label' => 'Impressions',
                          'aggregate' => 'sum', 'display' => 'perc_of_row' },
                        { 'field' => "kpi:#{Kpi.interactions.id}", 'label' => 'Interactions',
                          'aggregate' => 'sum', 'display' => 'perc_of_total', 'precision' => '1' },
                        { 'field' => "kpi:#{Kpi.samples.id}", 'label' => 'Samples',
                          'aggregate' => 'sum', 'display' => 'perc_of_column', 'precision' => '0' }
                      ]
      )

      results = report.fetch_page
      expect(results[0]['campaign_name']).to eql 'Campaign 1'
      expect(results[0]['values']).to eql [300.0, 700.0, 20.0, 40.0, 10.0, 10.0]
      expect(report.format_values(results[0]['values'])).to eql ['30.00%', '70.00%', '10.0%', '20.0%', '20%', '14%']

      expect(results[1]['campaign_name']).to eql 'Campaign 2'
      expect(results[1]['values']).to eql [200.0, 100.0, 80.0, 60.0, 40.0, 60.0]
      expect(report.format_values(results[1]['values'])).to eql ['66.67%', '33.33%', '40.0%', '30.0%', '80%', '86%']
    end

    it "should only apply the 'display' formula to values that have any selected - with columns" do
      campaign1 = create(:campaign, company: company, name: 'Campaign 1')
      campaign2 = create(:campaign, company: company, name: 'Campaign 2')
      create(:event, campaign: campaign1,
                     place: create(:place, name: 'Bar 1', state: 'State 1'),
                     results: { impressions: 300, interactions: 20, samples: 10 })

      create(:event, campaign: campaign1,
                     place: create(:place, name: 'Bar 2', state: 'State 2'),
                     results: { impressions: 700, interactions: 40, samples: 10 })

      create(:event, campaign: campaign2,
                     place: create(:place, name: 'Bar 3', state: 'State 1'),
                     results: { impressions: 200, interactions: 80, samples: 40 })

      create(:event, campaign: campaign2,
                     place: create(:place, name: 'Bar 4', state: 'State 2'),
                     results: { impressions: 100, interactions: 60, samples: 60 })

      report = create(:report,
                      company: company,
                      columns: [{ 'field' => 'values', 'label' => 'Values' },
                                { 'field' => 'place:state', 'label' => 'State' }],
                      rows:    [{ 'field' => 'campaign:name', 'label' => 'Campaign Name' }],
                      values:  [
                        { 'field' => "kpi:#{Kpi.impressions.id}", 'label' => 'Impressions',
                          'aggregate' => 'sum', 'display' => 'perc_of_row' },
                        { 'field' => "kpi:#{Kpi.interactions.id}", 'label' => 'Interactions',
                          'aggregate' => 'sum', 'display' => '' },
                        { 'field' => "kpi:#{Kpi.samples.id}", 'label' => 'Samples',
                          'aggregate' => 'sum', 'display' => nil }
                      ]
      )

      results = report.fetch_page
      expect(results[0]['campaign_name']).to eql 'Campaign 1'
      expect(results[0]['values']).to eql [300.0, 700.0, 20.0, 40.0, 10.0, 10.0]
      expect(report.format_values(results[0]['values'])).to eql [
        '30.00%', '70.00%', '20.00', '40.00', '10.00', '10.00']

      expect(results[1]['campaign_name']).to eql 'Campaign 2'
      expect(results[1]['values']).to eql [200.0, 100.0, 80.0, 60.0, 40.0, 60.0]
      expect(report.format_values(results[1]['values'])).to eql [
        '66.67%', '33.33%', '80.00', '60.00', '40.00', '60.00']
    end

    it "should olny apply the 'display' formula to values that have any selected - without columns" do
      campaign1 = create(:campaign, company: company, name: 'Campaign 1')
      campaign2 = create(:campaign, company: company, name: 'Campaign 2')
      create(:event, campaign: campaign1,
                     results: { impressions: 300, interactions: 20, samples: 10 })

      create(:event, campaign: campaign1,
                     results: { impressions: 700, interactions: 40, samples: 10 })

      create(:event, campaign: campaign2,
                     results: { impressions: 200, interactions: 80, samples: 40 })

      create(:event, campaign: campaign2,
                     results: { impressions: 100, interactions: 60, samples: 60 })

      report = create(:report,
                      company: company,
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'campaign:name', 'label' => 'Campaign Name' }],
                      values:  [
                        { 'field' => "kpi:#{Kpi.impressions.id}", 'label' => 'Impressions',
                          'aggregate' => 'sum', 'display' => 'perc_of_row' },
                        { 'field' => "kpi:#{Kpi.interactions.id}", 'label' => 'Interactions',
                          'aggregate' => 'sum', 'display' => '' },
                        { 'field' => "kpi:#{Kpi.samples.id}", 'label' => 'Samples',
                          'aggregate' => 'sum', 'display' => nil }
                      ]
      )

      # The first value is displayed as % of row
      results = report.fetch_page
      expect(results[0]['campaign_name']).to eql 'Campaign 1'
      expect(results[0]['values']).to eql [1000.0, 60.0, 20.0]
      expect(report.format_values(results[0]['values'])).to eql ['100.00%', '60.00', '20.00']

      expect(results[1]['campaign_name']).to eql 'Campaign 2'
      expect(results[1]['values']).to eql [300.0, 140.0, 100.0]
      expect(report.format_values(results[1]['values'])).to eql ['100.00%', '140.00', '100.00']

      # The first value is displayed as % of column
      report = create(:report,
                      company: company,
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'campaign:name', 'label' => 'Campaign Name' }],
                      values:  [
                        { 'field' => "kpi:#{Kpi.impressions.id}", 'label' => 'Impressions',
                          'aggregate' => 'sum', 'display' => 'perc_of_column' },
                        { 'field' => "kpi:#{Kpi.interactions.id}", 'label' => 'Interactions',
                          'aggregate' => 'sum', 'display' => '' },
                        { 'field' => "kpi:#{Kpi.samples.id}", 'label' => 'Samples',
                          'aggregate' => 'sum', 'display' => nil }
                      ]
      )

      results = report.fetch_page
      expect(results[0]['campaign_name']).to eql 'Campaign 1'
      expect(results[0]['values']).to eql [1000.0, 60.0, 20.0]
      expect(report.format_values(results[0]['values'])).to eql ['76.92%', '60.00', '20.00']

      expect(results[1]['campaign_name']).to eql 'Campaign 2'
      expect(results[1]['values']).to eql [300.0, 140.0, 100.0]
      expect(report.format_values(results[1]['values'])).to eql ['23.08%', '140.00', '100.00']

      # The first value is displayed as % of total
      report = create(:report,
                      company: company,
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'campaign:name', 'label' => 'Campaign Name' }],
                      values:  [
                        { 'field' => "kpi:#{Kpi.impressions.id}", 'label' => 'Impressions',
                          'aggregate' => 'sum', 'display' => 'perc_of_total' },
                        { 'field' => "kpi:#{Kpi.interactions.id}", 'label' => 'Interactions',
                          'aggregate' => 'sum', 'display' => '' },
                        { 'field' => "kpi:#{Kpi.samples.id}", 'label' => 'Samples',
                          'aggregate' => 'sum', 'display' => nil }
                      ]
      )

      results = report.fetch_page
      expect(results[0]['campaign_name']).to eql 'Campaign 1'
      expect(results[0]['values']).to eql [1000.0, 60.0, 20.0]
      expect(report.format_values(results[0]['values'])).to eql ['76.92%', '60.00', '20.00']

      expect(results[1]['campaign_name']).to eql 'Campaign 2'
      expect(results[1]['values']).to eql [300.0, 140.0, 100.0]
      expect(report.format_values(results[1]['values'])).to eql ['23.08%', '140.00', '100.00']
    end

    it "should olny apply the 'display' formula to values that have any selected - without multiple rows" do
      campaign1 = create(:campaign, company: company, name: 'Campaign 1')
      campaign2 = create(:campaign, company: company, name: 'Campaign 2')
      create(:event, campaign: campaign1,
                     place: create(:place, name: 'Bar 1'),
                     results: { impressions: 300, interactions: 20, samples: 10 })

      create(:event, campaign: campaign1,
                     place: create(:place, name: 'Bar 2'),
                     results: { impressions: 700, interactions: 40, samples: 10 })

      create(:event, campaign: campaign2,
                     place: create(:place, name: 'Bar 3'),
                     results: { impressions: 200, interactions: 80, samples: 40 })

      create(:event, campaign: campaign2,
                     place: create(:place, name: 'Bar 4'),
                     results: { impressions: 100, interactions: 60, samples: 60 })

      report = create(:report,
                      company: company,
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'place:name', 'label' => 'Venue Name' },
                                { 'field' => 'campaign:name', 'label' => 'Campaign Name' }],
                      values:  [
                        { 'field' => "kpi:#{Kpi.impressions.id}", 'label' => 'Impressions',
                          'aggregate' => 'sum', 'display' => 'perc_of_row' },
                        { 'field' => "kpi:#{Kpi.interactions.id}", 'label' => 'Interactions',
                          'aggregate' => 'sum', 'display' => '' },
                        { 'field' => "kpi:#{Kpi.samples.id}", 'label' => 'Samples',
                          'aggregate' => 'sum', 'display' => nil }
                      ]
      )

      # The first value is displayed as % of row
      results = report.fetch_page
      expect(results[0]['place_name']).to eql 'Bar 1'
      expect(results[0]['campaign_name']).to eql 'Campaign 1'
      expect(results[0]['values']).to eql [300.0, 20.0, 10.0]
      expect(report.format_values(results[0]['values'])).to eql ['100.00%', '20.00', '10.00']

      expect(results[1]['place_name']).to eql 'Bar 2'
      expect(results[1]['campaign_name']).to eql 'Campaign 1'
      expect(results[1]['values']).to eql [700.0, 40.0, 10.0]
      expect(report.format_values(results[1]['values'])).to eql ['100.00%', '40.00', '10.00']

      expect(results[2]['place_name']).to eql 'Bar 3'
      expect(results[2]['campaign_name']).to eql 'Campaign 2'
      expect(results[2]['values']).to eql [200.0, 80.0, 40.0]
      expect(report.format_values(results[2]['values'])).to eql ['100.00%', '80.00', '40.00']

      expect(results[3]['place_name']).to eql 'Bar 4'
      expect(results[3]['campaign_name']).to eql 'Campaign 2'
      expect(results[3]['values']).to eql [100.0, 60.0, 60.0]
      expect(report.format_values(results[3]['values'])).to eql ['100.00%', '60.00', '60.00']

      # The first value is displayed as % of column and % of total
      %w(perc_of_column perc_of_total).each do |display|
        report = create(:report,
                        company: company,
                        columns: [{ 'field' => 'values', 'label' => 'Values' }],
                        rows:    [{ 'field' => 'place:name', 'label' => 'Venue Name' },
                                  { 'field' => 'campaign:name', 'label' => 'Campaign Name' }],
                        values:  [
                          { 'field' => "kpi:#{Kpi.impressions.id}", 'label' => 'Impressions',
                            'aggregate' => 'sum', 'display' => display },
                          { 'field' => "kpi:#{Kpi.interactions.id}", 'label' => 'Interactions',
                            'aggregate' => 'sum', 'display' => '' },
                          { 'field' => "kpi:#{Kpi.samples.id}", 'label' => 'Samples',
                            'aggregate' => 'sum', 'display' => nil }
                        ]
        )

        # The first value is displayed as % of row
        results = report.fetch_page
        expect(results[0]['place_name']).to eql 'Bar 1'
        expect(results[0]['campaign_name']).to eql 'Campaign 1'
        expect(results[0]['values']).to eql [300.0, 20.0, 10.0]
        expect(report.format_values(results[0]['values'])).to eql ['23.08%', '20.00', '10.00']

        expect(results[1]['place_name']).to eql 'Bar 2'
        expect(results[1]['campaign_name']).to eql 'Campaign 1'
        expect(results[1]['values']).to eql [700.0, 40.0, 10.0]
        expect(report.format_values(results[1]['values'])).to eql ['53.85%', '40.00', '10.00']

        expect(results[2]['place_name']).to eql 'Bar 3'
        expect(results[2]['campaign_name']).to eql 'Campaign 2'
        expect(results[2]['values']).to eql [200.0, 80.0, 40.0]
        expect(report.format_values(results[2]['values'])).to eql ['15.38%', '80.00', '40.00']

        expect(results[3]['place_name']).to eql 'Bar 4'
        expect(results[3]['campaign_name']).to eql 'Campaign 2'
        expect(results[3]['values']).to eql [100.0, 60.0, 60.0]
        expect(report.format_values(results[3]['values'])).to eql ['7.69%', '60.00', '60.00']
      end

    end
  end

  describe '#columns_totals' do
    let(:company) { create(:company) }
    let(:campaign) { create(:campaign, name: 'Guaro Cacique 2013', company: company) }
    before do
      Kpi.create_global_kpis
    end

    it 'should return the totals for all the values' do
      campaign2 = create(:campaign, name: 'Other', company: company)
      create(:event, campaign: campaign,  results: { impressions: 100 })
      create(:event, campaign: campaign,  results: { impressions: 200 })
      create(:event, campaign: campaign2, results: { impressions: 100 })

      report = create(:report,
                      company: company,
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'campaign:name', 'label' => 'Campaign Name' }],
                      values:  [{ 'field' => "kpi:#{Kpi.impressions.id}", 'label' => '% of column Impressions',
                                  'aggregate' => 'sum' }]
      )

      expect(report.report_columns).to match_array ['% of column Impressions']
      expect(report.columns_totals).to eql [400.0]
    end

    it 'should return the totals for the value on each column' do
      place_in_ca = create(:place, city: 'Los Angeles', state: 'California')
      place_in_tx = create(:place, city: 'Houston', state: 'Texas')
      place_in_az = create(:place, city: 'Phoenix', state: 'Arizona')
      campaign2 = create(:campaign, name: 'Other', company: company)
      create(:event, campaign: campaign,  results: { impressions: 100 }, place: place_in_ca)
      create(:event, campaign: campaign,  results: { impressions: 200 }, place: place_in_tx)
      create(:event, campaign: campaign2, results: { impressions: 500 }, place: place_in_ca)
      create(:event, campaign: campaign,  results: { impressions: 50 }, place: place_in_az)

      report = create(:report,
                      company: company,
                      columns: [{ 'field' => 'place:state', 'label' => 'State' },
                                { 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'campaign:name', 'label' => 'Campaign Name' }],
                      values:  [{ 'field' => "kpi:#{Kpi.impressions.id}", 'label' => '% of column Impressions',
                                  'aggregate' => 'sum', 'display' => '' }]
      )

      expect(report.report_columns).to match_array [
        'Arizona||% of column Impressions', 'California||% of column Impressions',
        'Texas||% of column Impressions']
      expect(report.columns_totals).to eql [50.0, 600.0, 200.0]
    end

    it 'should return the totals for each value on each column' do
      place_in_ca = create(:place, city: 'Los Angeles', state: 'California')
      place_in_tx = create(:place, city: 'Houston', state: 'Texas')
      place_in_az = create(:place, city: 'Phoenix', state: 'Arizona')
      campaign2 = create(:campaign, name: 'Other', company: company)
      create(:event, campaign: campaign,  results: { impressions: 100, interactions: 10 }, place: place_in_ca)
      create(:event, campaign: campaign,  results: { impressions: 200, interactions: 20 }, place: place_in_tx)
      create(:event, campaign: campaign2, results: { impressions: 500, interactions: 50 }, place: place_in_ca)
      create(:event, campaign: campaign,  results: { impressions: 50, interactions: 5 }, place: place_in_az)

      report = create(:report,
                      company: company,
                      columns: [{ 'field' => 'place:state', 'label' => 'State' },
                                { 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'campaign:name', 'label' => 'Campaign Name' }],
                      values:  [
                        { 'field' => "kpi:#{Kpi.impressions.id}", 'label' => 'Impressions',
                                  'aggregate' => 'sum' },
                        { 'field' => "kpi:#{Kpi.interactions.id}", 'label' => 'Interactions',
                                  'aggregate' => 'sum' }
                      ]
      )

      expect(report.report_columns).to match_array [
        'Arizona||Impressions', 'Arizona||Interactions', 'California||Impressions',
        'California||Interactions', 'Texas||Impressions', 'Texas||Interactions']
      expect(report.columns_totals).to eql [50.0, 5.0, 600.0, 60.0, 200.0, 20.0]
    end
  end

  describe '#fetch_page' do
    let(:company) { create(:company) }
    let(:campaign) { create(:campaign, name: 'Guaro Cacique 2013', company: company) }
    let(:user) { create(:company_user, company: company) }

    before { Kpi.create_global_kpis }

    it 'returns nil if report has no rows, values and columns' do
      create(:event, campaign: campaign, results: { impressions: 100, interactions: 50 })
      report = create(:report, company: company, rows: [], values: [], columns: [])
      expect(report.fetch_page).to be_nil
    end

    it 'returns nil if report has rows but not values and columns' do
      create(:event, campaign: campaign, results: { impressions: 100, interactions: 50 })
      report = create(:report,
                      company: company,
                      rows:    [{ 'field' => 'event:start_date', 'label' => 'Start date' }]
      )
      page = report.fetch_page
      expect(report.rows).to_not be_empty
      expect(page).to be_nil
    end

    it 'returns a line for each different day where a event happens' do
      create(:event, start_date: '01/01/2014', end_date: '01/01/2014', campaign: campaign,
        results: { impressions: 100, interactions: 50 })
      create(:event, start_date: '01/12/2014', end_date: '01/12/2014', campaign: campaign,
        results: { impressions: 200, interactions: 150 })
      report = create(:report,
                      company: company,
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'event:start_date', 'label' => 'Start date' }],
                      values:  [{ 'field' => "kpi:#{Kpi.impressions.id}", 'label' => 'Impressions',
                                  'aggregate' => 'sum' }]
      )
      page = report.fetch_page
      expect(page).to eql [
        { 'event_start_date' => '2014/01/01', 'values' => [100.00] },
        { 'event_start_date' => '2014/01/12', 'values' => [200.00] }
      ]
    end

    it "returns a line for each event's user when adding a user field as a row" do
      user1 = create(:company_user, company: company, user: create(:user, first_name: 'Nicole', last_name: 'Aldana'))
      user2 = create(:company_user, company: company, user: create(:user, first_name: 'Nadia', last_name: 'Aldana'))
      event = create(:event, campaign: campaign, results: { impressions: 100, interactions: 50 })
      event.users << [user1, user2]
      report = create(:report,
                      company: company,
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'user:first_name', 'label' => 'First Name' }],
                      values:  [{ 'field' => "kpi:#{Kpi.impressions.id}", 'label' => 'Impressions',
                                  'aggregate' => 'sum' }]
      )
      page = report.fetch_page
      expect(page).to eql [
        { 'user_first_name' => 'Nadia', 'values' => [100.00] },
        { 'user_first_name' => 'Nicole', 'values' => [100.00] }
      ]
    end

    it "returns a line for each event's user (full name) when adding a user field as a row using" do
      user1 = create(:company_user, company: company, user: create(:user, first_name: 'Nicole', last_name: 'Aldana'))
      user2 = create(:company_user, company: company, user: create(:user, first_name: 'Nadia', last_name: 'Aldana'))
      event = create(:event, campaign: campaign, results: { impressions: 100, interactions: 50 })
      event.users << [user1, user2]
      report = create(:report,
                      company: company,
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'user:full_name', 'label' => 'Full Name' }],
                      values:  [{ 'field' => "kpi:#{Kpi.impressions.id}", 'label' => 'Impressions',
                                  'aggregate' => 'sum' }]
      )
      page = report.fetch_page
      expect(page).to eql [
        { 'user_full_name' => 'Nadia Aldana', 'values' => [100.00] },
        { 'user_full_name' => 'Nicole Aldana', 'values' => [100.00] }
      ]
    end

    it "returns a line for each team's user when adding a user field as a row and the team is part of the event" do
      user1 = create(:company_user, company: company, user: create(:user, first_name: 'Nicole', last_name: 'Aldana'))
      user2 = create(:company_user, company: company, user: create(:user, first_name: 'Nadia', last_name: 'Aldana'))
      team = create(:team, company: company)
      event = create(:event, campaign: campaign, results: { impressions: 100, interactions: 50 })
      create(:event, campaign: campaign, results: { impressions: 300, interactions: 300 }) # Another event
      team.users << [user1, user2]
      event.teams << team
      report = create(:report,
                      company: company,
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'user:first_name', 'label' => 'First Name' }],
                      values:  [{ 'field' => "kpi:#{Kpi.impressions.id}", 'label' => 'Impressions',
                                  'aggregate' => 'sum' }]
      )
      page = report.fetch_page
      expect(page).to eql [
        { 'user_first_name' => 'Nadia', 'values' => [100.00] },
        { 'user_first_name' => 'Nicole', 'values' => [100.00] },
        { 'user_first_name' => nil, 'values' => [300.00] }
      ]
    end

    it 'returns a line for each team  when adding a team field as a row and the team is part of the event' do
      team = create(:team, name: 'Power Rangers', company: company)
      event = create(:event, campaign: campaign, results: { impressions: 100, interactions: 50 })
      create(:event, campaign: campaign, results: { impressions: 300, interactions: 300 }) # Another event
      event.teams << team
      report = create(:report,
                      company: company,
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'team:name', 'label' => 'Team' }],
                      values:  [{ 'field' => "kpi:#{Kpi.impressions.id}", 'label' => 'Impressions',
                                  'aggregate' => 'sum' }]
      )
      page = report.fetch_page
      expect(page).to eql [
        { 'team_name' => 'Power Rangers', 'values' => [100.00] }
      ]
    end

    it 'returns a line for each activity type when adding an activity type field as a row' do
      event = create(:event, campaign: campaign, results: { impressions: 100, interactions: 50 })
      activity_type = create(:activity_type, name: 'SomeActivityName1', company: company)
      campaign.activity_types << activity_type

      create(:activity, activitable: event,
        activity_type: activity_type, company_user: user)

      report = create(:report,
                      company: company,
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'activity_type:name', 'label' => 'Activity Type' }],
                      values:  [{ 'field' => 'activity_type:user', 'label' => 'Impressions',
                                  'aggregate' => 'count' }]
      )
      page = report.fetch_page

      expect(page).to eql [
        { 'activity_type_name' => 'SomeActivityName1', 'values' => [1.0] }
      ]
    end

    it 'returns the correct number of events' do
      create(:event, campaign: campaign, results: { impressions: 100, interactions: 50 })
      create(:event, campaign: campaign, results: { impressions: 300, interactions: 300 }) # Another event
      report = create(:report,
                      company: company,
                      filters: [{ 'field' => "kpi:#{Kpi.interactions.id}", 'label' => 'Interactions' }],
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'campaign:name', 'label' => 'Campaign' }],
                      values:  [{ 'field' => "kpi:#{Kpi.events.id}", 'label' => 'Events',
                                  'aggregate' => 'sum' }]
      )
      page = report.fetch_page
      expect(page).to eql [
        { 'campaign_name' => campaign.name, 'values' => [2.00] }
      ]
    end

    it 'returns the correct number of promo hours' do
      create(:event, campaign: campaign, results: { impressions: 100, interactions: 50 })
      create(:event, campaign: campaign, results: { impressions: 300, interactions: 300 })
      report = create(:report,
                      company: company,
                      filters: [{ 'field' => "kpi:#{Kpi.interactions.id}", 'label' => 'Interactions' }],
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'campaign:name', 'label' => 'Campaign' }],
                      values:  [{ 'field' => "kpi:#{Kpi.promo_hours.id}", 'label' => 'Promo Hours',
                                  'aggregate' => 'sum' }]
      )
      page = report.fetch_page
      expect(page).to eql [
        { 'campaign_name' => campaign.name, 'values' => [4.00] }
      ]
    end

    it 'returns the correct number of photos' do
      event = create(:event, campaign: campaign, results: { impressions: 100, interactions: 50 })
      create_list(:attached_asset, 2, attachable: event, asset_type: 'photo')
      event = create(:event, campaign: campaign, results: { impressions: 300, interactions: 300 })
      create_list(:attached_asset, 2, attachable: event, asset_type: 'photo')

      campaign2 = create(:campaign, name: 'Zeta', company: company)
      create(:event, campaign: campaign2, results: { impressions: 300, interactions: 300 })

      report = create(:report,
                      company: company,
                      filters: [{ 'field' => "kpi:#{Kpi.interactions.id}", 'label' => 'Interactions' }],
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'campaign:name', 'label' => 'Campaign' }],
                      values:  [{ 'field' => "kpi:#{Kpi.photos.id}", 'label' => 'Photos',
                                  'aggregate' => 'count' }]
      )
      page = report.fetch_page
      expect(page).to eql [
        { 'campaign_name' => campaign.name, 'values' => [4.00] },
        { 'campaign_name' => campaign2.name, 'values' => [0.00] }
      ]
    end

    it 'returns the correct number of comments' do
      event = create(:event, campaign: campaign, results: { impressions: 100, interactions: 50 })
      create_list(:comment, 2, commentable: event)
      event = create(:event, campaign: campaign, results: { impressions: 300, interactions: 300 })
      create_list(:comment, 2, commentable: event)

      campaign2 = create(:campaign, name: 'Zeta', company: company)
      create(:event, campaign: campaign2, results: { impressions: 300, interactions: 300 })

      report = create(:report,
                      company: company,
                      filters: [{ 'field' => "kpi:#{Kpi.interactions.id}", 'label' => 'Interactions' }],
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'campaign:name', 'label' => 'Campaign' }],
                      values:  [{ 'field' => "kpi:#{Kpi.comments.id}", 'label' => 'Photos',
                                  'aggregate' => 'count' }]
      )
      page = report.fetch_page
      expect(page).to eql [
        { 'campaign_name' => campaign.name, 'values' => [4.00] },
        { 'campaign_name' => campaign2.name, 'values' => [0.00] }
      ]
    end

    it 'returns the correct amount of expenses' do
      event = create(:event, campaign: campaign, results: { impressions: 100, interactions: 50 })
      create(:event_expense, event: event, amount: 160)
      event = create(:event, campaign: campaign, results: { impressions: 300, interactions: 300 })
      create(:event_expense, event: event, amount: 330)

      campaign2 = create(:campaign, name: 'Zeta', company: company)
      create(:event, campaign: campaign2, results: { impressions: 300, interactions: 300 })

      report = create(:report,
                      company: company,
                      filters: [{ 'field' => "kpi:#{Kpi.interactions.id}", 'label' => 'Interactions' }],
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'campaign:name', 'label' => 'Campaign' }],
                      values:  [{ 'field' => "kpi:#{Kpi.expenses.id}", 'label' => 'Expenses',
                                  'aggregate' => 'sum' }]
      )
      page = report.fetch_page
      expect(page).to eql [
        { 'campaign_name' => campaign.name, 'values' => [490.00] },
        { 'campaign_name' => campaign2.name, 'values' => [0.00] }
      ]

      # With COUNT aggregation method
      report = create(:report,
                      company: company,
                      filters: [{ 'field' => "kpi:#{Kpi.interactions.id}", 'label' => 'Interactions' }],
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'campaign:name', 'label' => 'Campaign' }],
                      values:  [{ 'field' => "kpi:#{Kpi.expenses.id}", 'label' => 'Expenses',
                                  'aggregate' => 'count' }]
      )
      page = report.fetch_page
      expect(page).to eql [
        { 'campaign_name' => campaign.name, 'values' => [2.00] },
        { 'campaign_name' => campaign2.name, 'values' => [0.00] }
      ]

      # With MIN aggregation method
      report = create(:report,
                      company: company,
                      filters: [{ 'field' => "kpi:#{Kpi.interactions.id}", 'label' => 'Interactions' }],
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'campaign:name', 'label' => 'Campaign' }],
                      values:  [{ 'field' => "kpi:#{Kpi.expenses.id}", 'label' => 'Expenses',
                                  'aggregate' => 'min' }]
      )
      page = report.fetch_page
      expect(page).to eql [
        { 'campaign_name' => campaign.name, 'values' => [160.00] },
        { 'campaign_name' => campaign2.name, 'values' => [0.00] }
      ]

      # With MAX aggregation method
      report = create(:report,
                      company: company,
                      filters: [{ 'field' => "kpi:#{Kpi.interactions.id}", 'label' => 'Interactions' }],
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'campaign:name', 'label' => 'Campaign' }],
                      values:  [{ 'field' => "kpi:#{Kpi.expenses.id}", 'label' => 'Expenses',
                                  'aggregate' => 'max' }]
      )
      page = report.fetch_page
      expect(page).to eql [
        { 'campaign_name' => campaign.name, 'values' => [330.00] },
        { 'campaign_name' => campaign2.name, 'values' => [0.00] }
      ]
    end

    it 'returns a line for each brand portfolio when adding a portfolio field as a row and the event is associated to any ' do
      campaign.assign_all_global_kpis
      brand_portfolio1 = create(:brand_portfolio, name: 'BP1', company: company)
      brand_portfolio2 = create(:brand_portfolio, name: 'BP2', company: company)
      brand = create(:brand)
      brand_portfolio1.brands << brand
      brand_portfolio2.brands << brand

      create(:event, start_date: '01/01/2014', end_date: '01/01/2014', campaign: campaign,
        results: { impressions: 100, interactions: 50 })

      campaign2 = create(:campaign, company: company)
      create(:event, start_date: '01/12/2014', end_date: '01/12/2014', campaign: campaign2,
        results: { impressions: 200, interactions: 150 })

      campaign3 = create(:campaign, company: company)
      create(:event, start_date: '01/13/2014', end_date: '01/13/2014', campaign: campaign3,
        results: { impressions: 300, interactions: 175 })

      # Campaign without brands or brand portfolios
      campaign4 = create(:campaign, company: company)
      create(:event, start_date: '01/15/2014', end_date: '01/15/2014', campaign: campaign4,
        results: { impressions: 350, interactions: 250 })

      # Make both campaigns to be related to the same brand
      campaign.brand_portfolios << brand_portfolio1
      campaign2.brands << brand
      campaign3.brand_portfolios << brand_portfolio2
      campaign2.brand_portfolios << brand_portfolio2

      report = create(:report,
                      company: company,
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'brand_portfolio:name', 'label' => 'Portfolio' }],
                      values:  [{ 'field' => "kpi:#{Kpi.impressions.id}", 'label' => 'Impressions',
                                  'aggregate' => 'sum' }]
      )
      page = report.fetch_page
      expect(page).to eql [
        { 'brand_portfolio_name' => 'BP1', 'values' => [300.0] },
        { 'brand_portfolio_name' => 'BP2', 'values' => [500.0] },
        { 'brand_portfolio_name' => nil, 'values' => [350.0] }
      ]

      # Filter by a brand portfolio
      report = create(:report,
                      company: company,
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'brand_portfolio:name', 'label' => 'Portfolio' }],
                      filters: [{ 'field' => 'brand_portfolio:name', 'label' => 'Portfolio' }],
                      values:  [{ 'field' => "kpi:#{Kpi.impressions.id}", 'label' => 'Impressions',
                                  'aggregate' => 'sum' }]
      )
      report.filter_params = { 'brand_portfolio:name' => ['BP1'] }
      page = report.fetch_page
      expect(page).to eql [
        { 'brand_portfolio_name' => 'BP1', 'values' => [300.0] }
      ]
    end

    it 'returns a line for each brand when adding a brand field as a row and the event is associated to any ' do
      campaign.assign_all_global_kpis
      brand1 = create(:brand, name: 'Brand1')
      brand2 = create(:brand, name: 'Brand2')
      brand_portfolio1 = create(:brand_portfolio, name: 'BP1', company: company)
      brand_portfolio2 = create(:brand_portfolio, name: 'BP2', company: company)
      brand_portfolio1.brands << brand1
      brand_portfolio2.brands << brand1
      brand_portfolio2.brands << brand2

      create(:event, start_date: '01/01/2014', end_date: '01/01/2014', campaign: campaign,
        results: { impressions: 100, interactions: 50 })

      campaign2 = create(:campaign, company: company)
      create(:event, start_date: '01/12/2014', end_date: '01/12/2014', campaign: campaign2,
        results: { impressions: 200, interactions: 150 })

      campaign3 = create(:campaign, company: company)
      create(:event, start_date: '01/13/2014', end_date: '01/13/2014', campaign: campaign3,
        results: { impressions: 300, interactions: 175 })

      # Campaign without brands or brand portfolios
      campaign4 = create(:campaign, company: company)
      create(:event, start_date: '01/15/2014', end_date: '01/15/2014', campaign: campaign4,
        results: { impressions: 350, interactions: 250 })

      # Make both campaigns to be related to the same brand
      campaign.brands << brand1
      campaign2.brand_portfolios << brand_portfolio1
      campaign3.brands << brand2

      report = create(:report,
                      company: company,
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'brand:name', 'label' => 'Portfolio' }],
                      values:  [{ 'field' => "kpi:#{Kpi.impressions.id}", 'label' => 'Impressions',
                                  'aggregate' => 'sum' }]
      )
      page = report.fetch_page
      expect(page).to eql [
        { 'brand_name' => 'Brand1', 'values' => [300.0] },
        { 'brand_name' => 'Brand2', 'values' => [300.0] },
        { 'brand_name' => nil, 'values' => [350.0] }
      ]

      # Filter by a brand portfolio
      report = create(:report,
                      company: company,
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'brand_portfolio:name', 'label' => 'Portfolio' }],
                      filters: [{ 'field' => 'brand_portfolio:name', 'label' => 'Portfolio' }],
                      values:  [{ 'field' => "kpi:#{Kpi.impressions.id}", 'label' => 'Impressions',
                                  'aggregate' => 'sum' }]
      )
      report.filter_params = { 'brand_portfolio:name' => ['BP1'] }
      page = report.fetch_page
      expect(page).to eql [
        { 'brand_portfolio_name' => 'BP1', 'values' => [300.0] }
      ]
    end

    it 'returns a line for each area when adding a area field as a row and the event is associated to any ' do
      campaign.assign_all_global_kpis
      area1 = create(:area, name: 'Area1')
      area2 = create(:area, name: 'Area2')
      chicago = create(:city, name: 'Chicago', state: 'Illinois', country: 'US')
      los_angeles = create(:city, name: 'Los Angeles', state: 'California', country: 'US')
      venue_in_chicago = create(:place, city: 'Chicago', state: 'Illinois', country: 'US')
      venue_in_la = create(:place, name: 'Bar L.A.', city: 'Los Angeles', state: 'California', country: 'US')
      venue_in_ny = create(:place, city: 'New York', state: 'New York', country: 'US')
      area1.places << chicago
      area2.places << los_angeles
      area2.places << venue_in_la

      create(:event, start_date: '01/01/2014', end_date: '01/01/2014', campaign: campaign,
        results: { impressions: 100, interactions: 50 }, place: venue_in_chicago)

      create(:event, start_date: '01/12/2014', end_date: '01/12/2014', campaign: campaign,
        results: { impressions: 200, interactions: 150 }, place: venue_in_la)

      create(:event, start_date: '01/13/2014', end_date: '01/13/2014', campaign: campaign,
        results: { impressions: 300, interactions: 175 }, place: venue_in_chicago)

      # Event without any Area
      create(:event, start_date: '01/15/2014', end_date: '01/15/2014', campaign: campaign,
        results: { impressions: 350, interactions: 250 }, place: venue_in_ny)

      report = create(:report,
                      company: company,
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'area:name', 'label' => 'Area' }],
                      values:  [{ 'field' => "kpi:#{Kpi.impressions.id}", 'label' => 'Impressions',
                                  'aggregate' => 'sum' }]
      )
      page = report.fetch_page
      expect(page).to eql [
        { 'area_name' => 'Area1', 'values' => [400.0] },
        { 'area_name' => 'Area2', 'values' => [200.0] },
        { 'area_name' => nil, 'values' => [350.0] }
      ]

      # Filter by a place
      report = create(:report,
                      company: company,
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'area:name', 'label' => 'Area' }],
                      filters: [{ 'field' => 'place:name', 'label' => 'Venue' }],
                      values:  [{ 'field' => "kpi:#{Kpi.impressions.id}", 'label' => 'Impressions',
                                  'aggregate' => 'sum' }]
      )
      report.filter_params = { 'place:name' => [venue_in_la.name] }
      page = report.fetch_page
      expect(page).to eql [
        { 'area_name' => 'Area2', 'values' => [200.0] }
      ]
    end

    it 'should work when adding fields from users and teams' do
      user = create(:company_user, company: company, user: create(:user, first_name: 'Green', last_name: 'Ranger'))
      team = create(:team, name: 'Power Rangers', company: company)
      team2 = create(:team, name: 'Transformers', company: company)
      team.users << user

      # A event with members but no teams
      event = create(:event, campaign: campaign, results: { impressions: 100, interactions: 50 })
      event.users << user

      # A event with a team without members
      event = create(:event, campaign: campaign, results: { impressions: 200, interactions: 100 })
      event.teams << team2

      # A event with a team with members
      event = create(:event, campaign: campaign, results: { impressions: 300, interactions: 150 })
      event.teams << team

      # A event without teams or members
      create(:event, campaign: campaign, results: { impressions: 300, interactions: 150 })
      report = create(:report,
                      company: company,
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'team:name', 'label' => 'Team' },
                                { 'field' => 'user:first_name', 'label' => 'Team' }],
                      values:  [{ 'field' => "kpi:#{Kpi.impressions.id}", 'label' => 'Impressions',
                                  'aggregate' => 'sum' }]
      )
      page = report.fetch_page
      expect(page).to eql [
        { 'team_name' => 'Power Rangers', 'user_first_name' => 'Green', 'values' => [300.00] },
        { 'team_name' => 'Transformers', 'user_first_name' => nil, 'values' => [200.00] },
        { 'team_name' => nil, 'user_first_name' => 'Green', 'values' => [100.00] },
        { 'team_name' => nil, 'user_first_name' => nil, 'values' => [300.00] }
      ]
    end

    it "returns the values for each report's row" do
      user1 = create(:company_user, company: company, user: create(:user, first_name: 'Nicole', last_name: 'Aldana'))
      user2 = create(:company_user, company: company, user: create(:user, first_name: 'Nadia', last_name: 'Aldana'))
      event = create(:event, campaign: campaign, results: { impressions: 100, interactions: 50 })
      event.users << [user1, user2]
      report = create(:report,
                      company: company,
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'user:last_name', 'label' => 'Last Name' },
                                { 'field' => 'user:first_name', 'label' => 'First Name' }],
                      values:  [{ 'field' => "kpi:#{Kpi.impressions.id}", 'label' => 'Impressions',
                                  'aggregate' => 'sum' }]
      )
      page = report.fetch_page
      expect(page).to eql [
        { 'user_last_name' => 'Aldana', 'user_first_name' => 'Nadia', 'values' => [100.00] },
        { 'user_last_name' => 'Aldana', 'user_first_name' => 'Nicole', 'values' => [100.00] }
      ]
    end

    it 'correctly handles multiple rows with fields from the event and users' do
      user1 = create(:company_user, company: company, user: create(:user, first_name: 'Nicole', last_name: 'Aldana'))
      user2 = create(:company_user, company: company, user: create(:user, first_name: 'Nadia', last_name: 'Aldana'))
      event = create(:event, campaign: campaign, results: { impressions: 100, interactions: 50 })
      event.users << [user1, user2]
      report = create(:report,
                      company: company,
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'event:start_date', 'label' => 'Start date' },
                                { 'field' => 'user:first_name', 'label' => 'First Name' }],
                      values:  [{ 'field' => "kpi:#{Kpi.impressions.id}", 'label' => 'Impressions',
                                  'aggregate' => 'sum' }]
      )
      page = report.fetch_page
      expect(page).to eql [
        { 'event_start_date' => '2019/01/23', 'user_first_name' => 'Nadia', 'values' => [100.00] },
        { 'event_start_date' => '2019/01/23', 'user_first_name' => 'Nicole', 'values' => [100.00] }
      ]
    end

    it 'returns a line for each role' do
      user = create(:company_user, company: company, role: create(:role, name: 'Market Manager'))
      event = create(:event, campaign: campaign, results: { impressions: 100, interactions: 50 })
      create(:event, campaign: campaign, results: { impressions: 300, interactions: 300 }) # Another event
      event.users << user
      report = create(:report,
                      company: company,
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'role:name', 'label' => 'Role' }],
                      values:  [{ 'field' => "kpi:#{Kpi.impressions.id}", 'label' => 'Impressions',
                                  'aggregate' => 'sum' }]
      )
      page = report.fetch_page
      expect(page).to eql [
        { 'role_name' => 'Market Manager', 'values' => [100.00] }
      ]
    end

    it 'returns a line for each campaign' do
      create(:event, campaign: campaign, place: create(:place, state: 'Texas', city: 'Houston'),
        results: { impressions: 100, interactions: 50 })
      create(:event, campaign: campaign, place: create(:place, state: 'California', city: 'Los Angeles'),
        results: { impressions: 200, interactions: 75 })
      create(:event, place: create(:place, state: 'California', city: 'San Francisco'),
                     campaign: create(:campaign, name: 'Ron Centenario FY12', company: company),
                     results: { impressions: 300, interactions: 150 })
      report = create(:report,
                      company: company,
                      columns: [{ 'field' => 'place:state', 'label' => 'State' },
                                { 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'campaign:name', 'label' => 'Campaign' }],
                      values:  [{ 'field' => "kpi:#{Kpi.impressions.id}", 'label' => 'Impressions',
                                  'aggregate' => 'sum' }]
      )
      page = report.fetch_page
      expect(report.report_columns).to match_array ['California||Impressions', 'Texas||Impressions']
      expect(page).to eql [
        { 'campaign_name' => 'Guaro Cacique 2013', 'values' => [200.0, 100.0] },
        { 'campaign_name' => 'Ron Centenario FY12', 'values' => [300.0, nil] }
      ]

      expect(report.report_columns).to eql ['California||Impressions', 'Texas||Impressions']
    end

    it 'should allow display values as a percentage of the column' do
      campaign2 = create(:campaign, name: 'Other', company: company)
      create(:event, campaign: campaign,  results: { impressions: 100 })
      create(:event, campaign: campaign,  results: { impressions: 200 })
      create(:event, campaign: campaign2, results: { impressions: 100 })

      report = create(:report,
                      company: company,
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'campaign:name', 'label' => 'Campaign Name' }],
                      values:  [{ 'field' => "kpi:#{Kpi.impressions.id}",
                                  'label' => '% of column Impressions', 'aggregate' => 'sum',
                                  'display' => 'perc_of_column' }]
      )

      page = report.fetch_page
      expect(report.report_columns).to match_array ['% of column Impressions']
      expect(page).to eql [
        { 'campaign_name' => 'Guaro Cacique 2013', 'values' => [300.0] },
        { 'campaign_name' => 'Other', 'values' => [100.0] }
      ]
      expect(report.format_values(page[0]['values'])).to eql ['75.00%']
      expect(report.format_values(page[1]['values'])).to eql ['25.00%']
    end

    it "should work when adding a table field as a value with the aggregation method 'count'" do
      create(:event, campaign: campaign, place: create(:place, state: 'Texas', city: 'Houston'),
        results: { impressions: 100, interactions: 50 })
      report = create(:report,
                      company: company,
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'campaign:name', 'label' => 'Campaign' }],
                      values:  [{ 'field' => 'place:name', 'label' => 'Venue Name',
                                  'aggregate' => 'count' }]
      )

      page = report.fetch_page
      expect(page).to eql [
        { 'campaign_name' => 'Guaro Cacique 2013', 'values' => [1.0] }
      ]
    end

    it "should work when adding a table field as a value with the aggregation method 'sum'" do
      create(:event, campaign: campaign, place: create(:place, state: 'Texas', city: 'Houston'),
        results: { impressions: 100, interactions: 50 })
      report = create(:report,
                      company: company,
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'campaign:name', 'label' => 'Campaign' }],
                      values:  [{ 'field' => 'place:name', 'label' => 'Venue Name',
                                  'aggregate' => 'sum' }]
      )

      page = report.fetch_page
      expect(page).to eql [
        { 'campaign_name' => 'Guaro Cacique 2013', 'values' => [0.0] }
      ]
    end

    it 'should work when adding percentage KPIs as a value' do
      event = create(:event, campaign: campaign, place: create(:place))
      kpi = create(:kpi, company: company, kpi_type: 'percentage', kpis_segments: [
        seg1 = build(:kpis_segment, text: 'Segment 1', ordering: 1),
        seg2 = build(:kpis_segment, text: 'Segment 2', ordering: 2),
        seg3 = build(:kpis_segment, text: 'Segment 3', ordering: 3)
      ])
      campaign.add_kpi kpi
      results = event.result_for_kpi(kpi)
      results.value = { seg1.id => 25, seg2.id => 75, seg3.id => '' }
      event.save # Save the event results

      report = create(:report,
                      company: company,
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'campaign:name', 'label' => 'Campaign' }],
                      values:  [{ 'field' => "kpi:#{kpi.id}", 'label' => 'Segmented Field',
                                  'aggregate' => 'avg' }]
      )

      page = report.fetch_page
      expect(report.report_columns).to eql [
        'Segmented Field: Segment 1', 'Segmented Field: Segment 2', 'Segmented Field: Segment 3'
      ]
      expect(page).to eql [
        { 'campaign_name' => 'Guaro Cacique 2013', 'values' => [25.0, 75.0, 0.0] }
      ]
    end

    it 'should work when adding count KPIs as a value' do
      kpi = create(:kpi, company: company, kpi_type: 'count', kpis_segments: [
        build(:kpis_segment, text: 'Yes', ordering: 1),
        build(:kpis_segment, text: 'No', ordering: 2)
      ])
      campaign.add_kpi kpi

      event = create(:event, campaign: campaign, place: create(:place))
      event.result_for_kpi(kpi).value = kpi.kpis_segments.first.id
      event.valid?
      expect(event.save).to be_truthy # Save the event results

      event = create(:event, campaign: campaign, place: create(:place))
      event.result_for_kpi(kpi).value = kpi.kpis_segments.second.id
      event.valid?
      expect(event.save).to be_truthy # Save the event results

      event = create(:event, campaign: campaign, place: create(:place))
      event.result_for_kpi(kpi).value = kpi.kpis_segments.second.id
      expect(event.save).to be_truthy # Save the event results

      report = create(:report,
                      company: company,
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'campaign:name', 'label' => 'Campaign' }],
                      values:  [{ 'field' => "kpi:#{kpi.id}", 'label' => 'Count Field',
                                  'aggregate' => 'count' }]
      )

      page = report.fetch_page
      expect(report.report_columns).to eql ['Count Field: Yes', 'Count Field: No']
      expect(page).to eql [
        { 'campaign_name' => 'Guaro Cacique 2013', 'values' => [1.0, 2.0] }
      ]
    end

    it 'should accept kpis as rows' do
      create(:event, campaign: campaign, results: { impressions: 123, interactions: 50 })

      create(:event, campaign: campaign, results: { impressions: 321, interactions: 25 })

      report = create(:report,
                      company: company,
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => "kpi:#{Kpi.interactions.id}", 'label' => 'Interactions' }],
                      values:  [{ 'field' => "kpi:#{Kpi.impressions.id}", 'label' => 'Impressions',
                                  'aggregate' => 'sum' }]
      )
      page = report.fetch_page
      expect(page).to eql [
        { "kpi_#{Kpi.interactions.id}" => '25', 'values' => [321.0] },
        { "kpi_#{Kpi.interactions.id}" => '50', 'values' => [123.0] }
      ]
    end

    it 'should accept kpis as columns' do
      create(:event, campaign: campaign, place: create(:place, name: 'Bar 1'),
        results: { impressions: 123, interactions: 50 })

      create(:event, campaign: campaign, place: create(:place, name: 'Bar 2'),
        results: { impressions: 321, interactions: 25 })

      report = create(:report,
                      company: company,
                      columns: [{ 'field' => 'values', 'label' => 'Values' },
                                { 'field' => "kpi:#{Kpi.interactions.id}", 'label' => 'Interactions' }],
                      rows:    [{ 'field' => 'place:name', 'label' => 'Interactions' }],
                      values:  [{ 'field' => "kpi:#{Kpi.impressions.id}", 'label' => 'Impressions',
                                  'aggregate' => 'sum' }]
      )
      page = report.fetch_page
      expect(page).to eql [
        { 'place_name' => 'Bar 1', 'values' => [nil, 123.0] },
        { 'place_name' => 'Bar 2', 'values' => [321.0, nil] }
      ]
    end

    describe 'with columns' do
      it 'returns all the values grouped by venue state' do
        place_in_ca = create(:place, city: 'Los Angeles', state: 'California')
        place_in_tx = create(:place, city: 'Houston', state: 'Texas')
        create(:event, start_date: '01/01/2014', end_date: '01/01/2014', campaign: campaign,
          place: place_in_ca, results: { impressions: 100, interactions: 50 })
        create(:event, start_date: '01/12/2014', end_date: '01/12/2014', campaign: campaign,
          place: place_in_tx, results: { impressions: 200, interactions: 150 })
        report = create(:report,
                        company: company,
                        columns: [{ 'field' => 'place:state', 'label' => 'State' },
                                  { 'field' => 'values', 'label' => 'Values' }],
                        rows:    [{ 'field' => 'event:start_date', 'label' => 'Start date' }],
                        values:  [{ 'field' => "kpi:#{Kpi.impressions.id}", 'label' => 'Impressions',
                                    'aggregate' => 'sum', 'precision' => '1' },
                                  { 'field' => "kpi:#{Kpi.interactions.id}", 'label' => 'Interactions',
                                    'aggregate' => 'avg', 'precision' => '3' }]
        )
        page = report.fetch_page
        expect(report.report_columns).to match_array [
          'California||Impressions', 'California||Interactions',
          'Texas||Impressions', 'Texas||Interactions']
        expect(page).to eql [
          { 'event_start_date' => '2014/01/01', 'values' => [100.00, 50.0, nil, nil] },
          { 'event_start_date' => '2014/01/12', 'values' => [nil, nil, 200.00, 150.0] }
        ]

        # Test to_csv
        csv = CSV.parse(report.to_csv)
        expect(csv[0]).to eql ['Start date', 'California/Impressions', 'California/Interactions',
                               'Texas/Impressions', 'Texas/Interactions']
        expect(csv[1]).to eql ['2014/01/01', '100.0', '50.000', nil, nil]
        expect(csv[2]).to eql ['2014/01/12', nil, nil, '200.0', '150.000']
      end

      it 'returns a line for each team  when adding a team field as a row and the team is part of the event' do
        team = create(:team, name: 'Power Rangers', company: company)
        event = create(:event, campaign: campaign, start_date: '01/01/2014', end_date: '01/01/2014',
          results: { impressions: 100, interactions: 50 })
        event.teams << team
        report = create(:report,
                        company: company,
                        columns: [{ 'field' => 'team:name', 'label' => 'Team' }, { 'field' => 'values', 'label' => 'Values' }],
                        rows:    [{ 'field' => 'event:start_date', 'label' => 'Start date' }],
                        values:  [{ 'field' => "kpi:#{Kpi.impressions.id}", 'label' => 'Impressions', 'aggregate' => 'sum' }]
        )
        page = report.fetch_page
        expect(page).to eql [
          { 'event_start_date' => '2014/01/01', 'values' => [100.00] }
        ]
      end

      it 'returns the area names as columns' do
        campaign.assign_all_global_kpis
        area1 = create(:area, name: 'Area1')
        area2 = create(:area, name: 'Area2')
        chicago = create(:place, city: 'Chicago', state: 'Illinois', country: 'US', types: ['political'])
        los_angeles = create(:place, city: 'Los Angeles', state: 'California', country: 'US', types: ['political'])
        venue_in_chicago = create(:place, city: 'Chicago', state: 'Illinois', country: 'US', types: ['establishment'])
        venue_in_la = create(:place, city: 'Los Angeles', state: 'California', country: 'US', types: ['establishment'])
        venue_in_ny = create(:place, city: 'New York', state: 'New York', country: 'US', types: ['establishment'])
        area1.places << chicago
        area2.places << los_angeles
        area2.places << venue_in_la

        create(:event, start_date: '01/01/2014', end_date: '01/01/2014', campaign: campaign,
          results: { impressions: 100, interactions: 50 }, place: venue_in_chicago)

        create(:event, start_date: '01/12/2014', end_date: '01/12/2014', campaign: campaign,
          results: { impressions: 200, interactions: 150 }, place: venue_in_la)

        create(:event, start_date: '01/13/2014', end_date: '01/13/2014', campaign: campaign,
          results: { impressions: 300, interactions: 175 }, place: venue_in_chicago)

        # Event without any Area
        create(:event, start_date: '01/15/2014', end_date: '01/15/2014', campaign: campaign,
          results: { impressions: 350, interactions: 250 }, place: venue_in_ny)

        report = create(:report,
                        company: company,
                        columns: [{ 'field' => 'area:name', 'label' => 'Area' }, { 'field' => 'values', 'label' => 'Values' }],
                        rows:    [{ 'field' => 'place:name', 'label' => 'Venue' }],
                        values:  [{ 'field' => "kpi:#{Kpi.impressions.id}", 'label' => 'Impressions', 'aggregate' => 'sum' }]
        )
        page = report.fetch_page
        expect(report.report_columns).to match_array ['Area1||Impressions', 'Area2||Impressions', '||Impressions']
        expect(page).to eql [
          { 'place_name' => venue_in_chicago.name, 'values' => [400.0, nil, nil] },
          { 'place_name' => venue_in_la.name, 'values' => [nil, 200.0, nil] },
          { 'place_name' => venue_in_ny.name, 'values' => [nil, nil, 350.0] }
        ]
      end
    end

    describe 'activity types' do
      it 'returns a line for each different value for a form field' do
        form_field = create(:form_field, type: 'FormField::Text',
                                         fieldable: create(:activity_type, company: company))
        form_field2 = create(:form_field, type: 'FormField::Number', fieldable: form_field.fieldable)
        campaign.activity_types << form_field.fieldable

        event = create(:event, campaign: campaign)
        event2 = create(:event, campaign: campaign)

        activity = create(:activity, activitable: event,
          activity_type: form_field.fieldable, company_user: user)
        activity.results_for([form_field]).first.value = 'First Result'
        activity.results_for([form_field2]).first.value = 150
        activity.save

        activity = create(:activity, activitable: event,
          activity_type: form_field.fieldable, company_user: user)
        activity.results_for([form_field]).first.value = 'First Result'
        activity.results_for([form_field2]).first.value = 15
        activity.save

        activity = create(:activity, activitable: event2,
          activity_type: form_field.fieldable, company_user: user)
        activity.results_for([form_field]).first.value = 'Another Result'
        activity.results_for([form_field2]).first.value = 200
        activity.save

        report = create(:report,
                        company: company,
                        columns: [{ 'field' => 'values', 'label' => 'Values' }],
                        rows:    [{ 'field' => "form_field:#{form_field.id}", 'label' => 'Form Field' }],
                        values:  [{ 'field' => "form_field:#{form_field2.id}", 'label' => 'Numeric Field', 'aggregate' => 'sum' }]
        )
        page = report.fetch_page
        expect(page).to eql [
          { "form_field_#{form_field.id}" => 'Another Result', 'values' => [200.00] },
          { "form_field_#{form_field.id}" => 'First Result', 'values' => [165.00] }
        ]
      end

      it 'returns a line for each different date for an activity' do
        form_field = create(:form_field, type: 'FormField::Number',
                                         fieldable: create(:activity_type, company: company))
        campaign.activity_types << form_field.fieldable

        event = create(:event, campaign: campaign,
                               results: { impressions: 100, interactions: 50 })
        event2 = create(:event, campaign: campaign,
                                results: { impressions: 200, interactions: 150 })

        activity = create(:activity, activitable: event,
          activity_type: form_field.fieldable, company_user: user, activity_date: Date.today)
        activity.results_for([form_field]).first.value = '100'
        activity.save

        activity = create(:activity, activitable: event,
          activity_type: form_field.fieldable, company_user: user, activity_date: Date.today)
        activity.results_for([form_field]).first.value = '200'
        activity.save

        activity = create(:activity, activitable: event,
          activity_type: form_field.fieldable, company_user: user, activity_date: Date.yesterday)
        activity.results_for([form_field]).first.value = '75'
        activity.save

        activity = create(:activity, activitable: event2,
          activity_type: form_field.fieldable, company_user: user, activity_date: Date.yesterday)
        activity.results_for([form_field]).first.value = '30'
        activity.save

        report = create(:report,
                        company: company,
                        columns: [{ 'field' => 'values', 'label' => 'Values' }],
                        rows:    [{ 'field' => 'activity_type:date', 'label' => 'Date' }],
                        values:  [{ 'field' => "form_field:#{form_field.id}", 'label' => 'Field1', 'aggregate' => 'sum' }]
        )
        page = report.fetch_page
        expect(page).to eql [
          { 'activity_type_date' => Date.yesterday.to_s(:ymd), 'values' => [105.00] },
          { 'activity_type_date' => Date.today.to_s(:ymd), 'values' => [300.00] }
        ]
      end

      it 'returns a line for each different user for an activity' do
        user2 = create(:company_user,
                       company: company,
                       user: create(:user, first_name: 'Luis', last_name: 'Perez'))
        form_field = create(:form_field, type: 'FormField::Number', fieldable: create(:activity_type, company: company))
        campaign.activity_types << form_field.fieldable

        event = create(:event, campaign: campaign,
                               results: { impressions: 100, interactions: 50 })
        event2 = create(:event, campaign: campaign,
                                results: { impressions: 200, interactions: 150 })

        activity = create(:activity, activitable: event,
          activity_type: form_field.fieldable, company_user: user)
        activity.results_for([form_field]).first.value = '100'
        activity.save

        activity = create(:activity, activitable: event,
          activity_type: form_field.fieldable, company_user: user)
        activity.results_for([form_field]).first.value = '200'
        activity.save

        activity = create(:activity, activitable: event,
          activity_type: form_field.fieldable, company_user: user2)
        activity.results_for([form_field]).first.value = '75'
        activity.save

        activity = create(:activity, activitable: event2,
          activity_type: form_field.fieldable, company_user: user2)
        activity.results_for([form_field]).first.value = '30'
        activity.save

        report = create(:report,
                        company: company,
                        columns: [{ 'field' => 'values', 'label' => 'Values' }],
                        rows:    [{ 'field' => 'activity_type:user', 'label' => 'User' }],
                        values:  [{ 'field' => "form_field:#{form_field.id}", 'label' => 'Field1', 'aggregate' => 'sum' }]
        )
        page = report.fetch_page
        expect(page).to eql [
          { 'activity_type_user' => user2.full_name, 'values' => [105.00] },
          { 'activity_type_user' => user.full_name, 'values' => [300.00] }
        ]
      end

      it 'returns the values for the numeric fields' do
        form_field = create(:form_field, type: 'FormField::Number',
                                         fieldable: create(:activity_type, company: company))
        campaign.activity_types << form_field.fieldable

        event = create(:event, start_date: '01/01/2014', end_date: '01/01/2014', campaign: campaign,
          results: { impressions: 100, interactions: 50 })
        create(:event, start_date: '01/12/2014', end_date: '01/12/2014', campaign: campaign,
          results: { impressions: 200, interactions: 150 })

        activity = create(:activity, activitable: event,
          activity_type: form_field.fieldable, company_user: user)
        activity.results_for([form_field]).first.value = 333
        activity.save

        activity = create(:activity, activitable: event,
          activity_type: form_field.fieldable, company_user: user)
        activity.results_for([form_field]).first.value = 222
        activity.save

        report = create(:report,
                        company: company,
                        columns: [{ 'field' => 'values', 'label' => 'Values' }],
                        rows:    [{ 'field' => 'campaign:name', 'label' => 'Form Field' }],
                        values:  [
                          { 'field' => "kpi:#{Kpi.impressions.id}", 'label' => 'Impressions', 'aggregate' => 'sum' },
                          { 'field' => "form_field:#{form_field.id}", 'label' => 'Numeric Field', 'aggregate' => 'sum' }
                        ]
        )
        page = report.fetch_page
        expect(page).to eql [
          { 'campaign_name' => 'Guaro Cacique 2013', 'values' => [300.00, 555.0] }
        ]
      end

      it 'should work when adding radio form fields as a value' do
        radio_field = create(:form_field, type: 'FormField::Radio',
                                          fieldable: create(:activity_type, company: company),
                                          options: [
                                            option1 = create(:form_field_option, name: 'Opt1', ordering: 1),
                                            option2 = create(:form_field_option, name: 'Opt2', ordering: 2)]
        )
        campaign.activity_types << radio_field.fieldable

        event = create(:event, start_date: '01/01/2014', end_date: '01/01/2014', campaign: campaign,
          results: { impressions: 100, interactions: 50 })
        create(:event, start_date: '01/12/2014', end_date: '01/12/2014', campaign: campaign,
          results: { impressions: 200, interactions: 150 })

        activity = create(:activity, activitable: event,
          activity_type: radio_field.fieldable, company_user: user)
        activity.results_for([radio_field]).first.value = option1.id
        activity.save

        activity = create(:activity, activitable: event,
          activity_type: radio_field.fieldable, company_user: user)
        activity.results_for([radio_field]).first.value = option2.id
        activity.save

        activity = create(:activity, activitable: event,
          activity_type: radio_field.fieldable, company_user: user)
        activity.results_for([radio_field]).first.value = option2.id
        activity.save

        report = create(:report,
                        company: company,
                        columns: [{ 'field' => 'values', 'label' => 'Values' }],
                        rows:    [{ 'field' => 'campaign:name', 'label' => 'Campaign' }],
                        values:  [{ 'field' => "form_field:#{radio_field.id}", 'label' => 'Radio Field', 'aggregate' => 'count' }]
        )

        page = report.fetch_page
        expect(report.report_columns).to eql ['Radio Field: Opt1', 'Radio Field: Opt2']
        expect(page).to eql [
          { 'campaign_name' => 'Guaro Cacique 2013', 'values' => [1.0, 2.0] }
        ]
      end

      it 'should work when adding checkboxes form fields as a value' do
        checkbox_field = create(:form_field, type: 'FormField::Checkbox',
                                             fieldable: create(:activity_type, company: company),
                                             options: [
                                               option1 = create(:form_field_option, name: 'Opt1', ordering: 1),
                                               option2 = create(:form_field_option, name: 'Opt2', ordering: 2)]
        )
        checkbox_field = FormField.find(checkbox_field.id)
        campaign.activity_types << checkbox_field.fieldable

        event = create(:event, start_date: '01/01/2014', end_date: '01/01/2014', campaign: campaign,
          results: { impressions: 100, interactions: 50 })
        create(:event, start_date: '01/12/2014', end_date: '01/12/2014', campaign: campaign,
          results: { impressions: 200, interactions: 150 })

        activity = create(:activity, activitable: event,
          activity_type: checkbox_field.fieldable, company_user: user)
        activity.results_for([checkbox_field]).first.value = [option1.id]
        expect(activity.save).to be_truthy

        activity = create(:activity, activitable: event,
          activity_type: checkbox_field.fieldable, company_user: user)
        activity.results_for([checkbox_field]).first.value = [option2.id]
        expect(activity.save).to be_truthy

        activity = create(:activity, activitable: event,
          activity_type: checkbox_field.fieldable, company_user: user)
        activity.results_for([checkbox_field]).first.value = [option1.id, option2.id]
        expect(activity.save).to be_truthy

        activity = create(:activity, activitable: event,
          activity_type: checkbox_field.fieldable, company_user: user)
        activity.results_for([checkbox_field]).first.value = [option2.id]
        expect(activity.save).to be_truthy

        report = create(:report,
                        company: company,
                        columns: [{ 'field' => 'values', 'label' => 'Values' }],
                        rows:    [{ 'field' => 'campaign:name', 'label' => 'Campaign' }],
                        values:  [{ 'field' => "form_field:#{checkbox_field.id}", 'label' => 'Checkbox Field', 'aggregate' => 'count' }]
        )

        page = report.fetch_page
        expect(report.report_columns).to eql ['Checkbox Field: Opt1', 'Checkbox Field: Opt2']
        expect(page).to eql [
          { 'campaign_name' => 'Guaro Cacique 2013', 'values' => [2.0, 3.0] }
        ]
      end

      it 'should work when adding percentage form fields as a value' do
        percentage_field = create(:form_field,
                                  type: 'FormField::Percentage',
                                  fieldable: create(:activity_type, company: company),
                                  options: [
                                    option1 = create(:form_field_option, name: 'Opt1', ordering: 1),
                                    option2 = create(:form_field_option, name: 'Opt2', ordering: 2),
                                    option3 = create(:form_field_option, name: 'Opt3', ordering: 3)]
        )
        percentage_field = FormField.find(percentage_field.id)
        campaign.activity_types << percentage_field.fieldable

        event = create(:event, start_date: '01/01/2014', end_date: '01/01/2014', campaign: campaign,
          results: { impressions: 100, interactions: 50 })
        create(:event, start_date: '01/12/2014', end_date: '01/12/2014', campaign: campaign,
          results: { impressions: 200, interactions: 150 })

        activity = create(:activity, activitable: event,
          activity_type: percentage_field.fieldable, company_user: user)
        activity.results_for([percentage_field]).first.value = { option1.id.to_s => 35, option2.id.to_s => 65 }
        expect(activity.save).to be_truthy

        activity = create(:activity, activitable: event,
          activity_type: percentage_field.fieldable, company_user: user)
        activity.results_for([percentage_field]).first.value = { option1.id.to_s => 20, option2.id.to_s => 80,  option3.id.to_s => '' }
        expect(activity.save).to be_truthy

        activity = create(:activity, activitable: event,
          activity_type: percentage_field.fieldable, company_user: user)
        activity.results_for([percentage_field]).first.value = { option1.id.to_s => 40, option2.id.to_s => 60,  option3.id.to_s => '' }
        expect(activity.save).to be_truthy

        report = create(:report,
                        company: company,
                        columns: [{ 'field' => 'values', 'label' => 'Values' }],
                        rows:    [{ 'field' => 'campaign:name', 'label' => 'Campaign' }],
                        values:  [{ 'field' => "form_field:#{percentage_field.id}",
                                    'label' => 'Percentage Field', 'aggregate' => 'avg' }]
        )

        page = report.fetch_page
        expect(report.report_columns).to eql ['Percentage Field: Opt1', 'Percentage Field: Opt2', 'Percentage Field: Opt3']
        expect(page).to eql [
          { 'campaign_name' => 'Guaro Cacique 2013', 'values' => [31.666666666666668, 68.33333333333333, 0.0] }
        ]
      end

      it 'works when adding radio fields as rows' do
        radio_field = create(:form_field,
                             type: 'FormField::Radio',
                             fieldable: create(:activity_type, company: company),
                             options: [
                               option1 = create(:form_field_option, name: 'Opt1'),
                               option2 = create(:form_field_option, name: 'Opt2')]
        )
        numeric_field = create(:form_field, type: 'FormField::Number', fieldable: radio_field.fieldable)
        campaign.activity_types << radio_field.fieldable

        event = create(:event, start_date: '01/01/2014', end_date: '01/01/2014', campaign: campaign,
          results: { impressions: 100, interactions: 50 })
        create(:event, start_date: '01/12/2014', end_date: '01/12/2014', campaign: campaign,
          results: { impressions: 200, interactions: 150 })

        activity = create(:activity, activitable: event,
          activity_type: radio_field.fieldable, company_user: user)
        activity.results_for([radio_field]).first.value = option1.id
        activity.results_for([numeric_field]).first.value = 100
        expect(activity.save).to be_truthy

        activity = create(:activity, activitable: event,
          activity_type: radio_field.fieldable, company_user: user)
        activity.results_for([radio_field]).first.value = option2.id
        activity.results_for([numeric_field]).first.value = 400
        expect(activity.save).to be_truthy

        report = create(:report,
                        company: company,
                        columns: [{ 'field' => 'values', 'label' => 'Values' }],
                        rows:     [{ 'field' => "form_field:#{radio_field.id}",
                                     'label' => 'Radio Field', 'aggregate' => 'sum' }],
                        values:  [{ 'field' => "form_field:#{numeric_field.id}",
                                    'label' => 'Numeric Field', 'aggregate' => 'sum' }]
        )
        page = report.fetch_page
        expect(page).to eql [
          { "form_field_#{radio_field.id}" => 'Opt1', 'values' => [100.00] },
          { "form_field_#{radio_field.id}" => 'Opt2', 'values' => [400.00] }
        ]
      end

      it 'works when adding checkboxes fields as rows' do
        checkbox_field = create(:form_field,
                                type: 'FormField::Checkbox',
                                fieldable: create(:activity_type, company: company),
                                options: [
                                  option1 = create(:form_field_option, name: 'Opt1'),
                                  option2 = create(:form_field_option, name: 'Opt2')]
        )
        checkbox_field = FormField.find(checkbox_field.id)
        numeric_field = create(:form_field, type: 'FormField::Number', fieldable: checkbox_field.fieldable)
        campaign.activity_types << checkbox_field.fieldable

        event = create(:event, start_date: '01/01/2014', end_date: '01/01/2014', campaign: campaign,
          results: { impressions: 100, interactions: 50 })
        create(:event, start_date: '01/12/2014', end_date: '01/12/2014', campaign: campaign,
          results: { impressions: 200, interactions: 150 })

        activity = create(:activity, activitable: event,
          activity_type: checkbox_field.fieldable, company_user: user)
        activity.results_for([checkbox_field]).first.value = [option1.id]
        activity.results_for([numeric_field]).first.value = 100
        expect(activity.save).to be_truthy

        activity = create(:activity, activitable: event,
          activity_type: checkbox_field.fieldable, company_user: user)
        activity.results_for([checkbox_field]).first.value = [option2.id]
        activity.results_for([numeric_field]).first.value = 400
        expect(activity.save).to be_truthy

        activity = create(:activity, activitable: event,
          activity_type: checkbox_field.fieldable, company_user: user)
        activity.results_for([checkbox_field]).first.value = [option1.id, option2.id]
        activity.results_for([numeric_field]).first.value = 300
        expect(activity.save).to be_truthy

        report = create(:report,
                        company: company,
                        columns: [{ 'field' => 'values', 'label' => 'Values' }],
                        rows:    [{ 'field' => "form_field:#{checkbox_field.id}",
                                    'label' => 'Radio Field', 'aggregate' => 'sum' }],
                        values:  [{ 'field' => "form_field:#{numeric_field.id}",
                                    'label' => 'Numeric Field', 'aggregate' => 'sum' }]
        )
        page = report.fetch_page
        expect(page).to eql [
          { "form_field_#{checkbox_field.id}" => 'Opt1', 'values' => [400.00] },
          { "form_field_#{checkbox_field.id}" => 'Opt2', 'values' => [700.00] }
        ]
      end

      it 'works when adding percentage fields as rows' do
        percentage_field = create(:form_field,
                                  type: 'FormField::Percentage',
                                  fieldable: create(:activity_type, company: company),
                                  options: [
                                    option1 = create(:form_field_option, name: 'Opt1'),
                                    option2 = create(:form_field_option, name: 'Opt2')]
        )
        percentage_field = FormField.find(percentage_field.id)
        numeric_field = create(:form_field, type: 'FormField::Number', fieldable: percentage_field.fieldable)
        campaign.activity_types << percentage_field.fieldable

        event = create(:event, start_date: '01/01/2014', end_date: '01/01/2014', campaign: campaign,
          results: { impressions: 100, interactions: 50 })
        create(:event, start_date: '01/12/2014', end_date: '01/12/2014', campaign: campaign,
          results: { impressions: 200, interactions: 150 })

        activity = create(:activity, activitable: event,
          activity_type: percentage_field.fieldable, company_user: user)
        activity.results_for([percentage_field]).first.value = { option1.id => 70, option2.id => 30 }
        activity.results_for([numeric_field]).first.value = 400
        activity.save

        activity = create(:activity, activitable: event,
          activity_type: percentage_field.fieldable, company_user: user)
        activity.results_for([percentage_field]).first.value = { option1.id => 70, option2.id => 30 }
        activity.results_for([numeric_field]).first.value = 100
        activity.save

        report = create(:report,
                        company: company,
                        columns: [{ 'field' => 'values', 'label' => 'Values' }],
                        rows:    [{ 'field' => "form_field:#{percentage_field.id}",
                                    'label' => 'Radio Field', 'aggregate' => 'sum' }],
                        values:  [{ 'field' => "form_field:#{numeric_field.id}",
                                    'label' => 'Numeric Field', 'aggregate' => 'sum' }]
        )
        page = report.fetch_page
        expect(page).to eql [
          { "form_field_#{percentage_field.id}" => 'Opt1', 'values' => [500.00] },
          { "form_field_#{percentage_field.id}" => 'Opt2', 'values' => [500.00] }
        ]
      end
    end
  end

  describe 'filtering' do
    let(:company) { create(:company) }
    let(:campaign) { create(:campaign, name: 'Guaro Cacique 2013', company: company) }
    before { Kpi.create_global_kpis }

    it 'can filter results by a range for numeric KPIs' do
      campaign.assign_all_global_kpis
      kpi = create(:kpi, company: company, kpi_type: 'number')
      campaign.add_kpi kpi
      event1 = create(:event, start_date: '01/01/2014', end_date: '01/01/2014', campaign: campaign,
        results: { impressions: 100, interactions: 50 })
      event1.result_for_kpi(kpi).value = 200
      event1.save

      create(:event, start_date: '01/12/2014', end_date: '01/12/2014', campaign: campaign,
        results: { impressions: 200, interactions: 150 })

      report = create(:report,
                      company: company,
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'event:start_date', 'label' => 'Start date' }],
                      filters: [{ 'field' => "kpi:#{kpi.id}", 'label' => 'A Numeric Filter' }],
                      values:  [{ 'field' => "kpi:#{Kpi.impressions.id}", 'label' => 'Impressions',
                                  'aggregate' => 'sum' }]
      )
      # With no filtering
      expect(report.fetch_page).to eql [
        { 'event_start_date' => '2014/01/01', 'values' => [100.00] },
        { 'event_start_date' => '2014/01/12', 'values' => [200.00] }
      ]

      report.filter_params = { "kpi:#{kpi.id}" => { 'min' => '100', 'max' => '300' } }
      expect(report.fetch_page).to eql [
        { 'event_start_date' => '2014/01/01', 'values' => [100.00] }
      ]
    end

    it 'can filter the results by area name' do
      campaign.assign_all_global_kpis
      area1 = create(:area, name: 'Area1')
      area2 = create(:area, name: 'Area2')
      chicago = create(:place, city: 'Chicago', state: 'Illinois', country: 'US', types: ['political'])
      los_angeles = create(:place, city: 'Los Angeles', state: 'California', country: 'US', types: ['political'])
      venue_in_chicago = create(:place, name: 'Place 001',
        city: 'Chicago', state: 'Illinois', country: 'US', types: ['establishment'])
      venue_in_la = create(:place, name: 'Place 002',
        city: 'Los Angeles', state: 'California', country: 'US', types: ['establishment'])
      venue_in_ny = create(:place, name: 'Place 003',
        city: 'New York', state: 'New York', country: 'US', types: ['establishment'])
      area1.places << chicago
      area2.places << los_angeles
      area2.places << venue_in_la

      create(:event, start_date: '01/01/2014', end_date: '01/01/2014', campaign: campaign,
        results: { impressions: 100, interactions: 50 }, place: venue_in_chicago)

      create(:event, start_date: '01/12/2014', end_date: '01/12/2014', campaign: campaign,
        results: { impressions: 200, interactions: 150 }, place: venue_in_la)

      create(:event, start_date: '01/13/2014', end_date: '01/13/2014', campaign: campaign,
        results: { impressions: 300, interactions: 175 }, place: venue_in_chicago)

      # Event without any Area
      create(:event, start_date: '01/15/2014', end_date: '01/15/2014', campaign: campaign,
        results: { impressions: 350, interactions: 250 }, place: venue_in_ny)

      report = create(:report,
                      company: company,
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'place:name', 'label' => 'Venue' }],
                      filters: [{ 'field' => 'area:name', 'label' => 'Area' }],
                      values:  [{ 'field' => "kpi:#{Kpi.impressions.id}",
                                  'label' => 'Impressions', 'aggregate' => 'sum' }]
      )
      page = report.fetch_page
      expect(page).to eql [
        { 'place_name' => venue_in_chicago.name, 'values' => [400.0] },
        { 'place_name' => venue_in_la.name, 'values' => [200.0] },
        { 'place_name' => venue_in_ny.name, 'values' => [350.0] }
      ]

      # With filtering
      report.filter_params = { 'area:name' => ['Area1'] }

      page = report.fetch_page
      expect(page).to eql [
        { 'place_name' => venue_in_chicago.name, 'values' => [400.0] }
      ]

      report.filter_params = { 'area:name' => ['Area2'] }

      page = report.fetch_page
      expect(page).to eql [
        { 'place_name' => venue_in_la.name, 'values' => [200.0] }
      ]
    end

    it 'can filter results by start/end times' do
      campaign.assign_all_global_kpis
      kpi = create(:kpi, company: company, kpi_type: 'number')
      campaign.add_kpi kpi
      event1 = create(:event, start_date: '01/01/2014', start_time: '10:00 AM',
        end_date: '01/01/2014', end_time: '11:00 AM', campaign: campaign,
        results: { impressions: 100, interactions: 50 })
      event1.result_for_kpi(kpi).value = 200
      event1.save

      create(:event, start_date: '01/12/2014', start_time: '01:00 AM',
                     end_date: '01/12/2014', end_time: '03:00 AM', campaign: campaign,
                     results: { impressions: 200, interactions: 150 })

      report = create(:report,
                      company: company,
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'event:start_date', 'label' => 'Start date' }],
                      filters: [{ 'field' => 'event:start_time', 'label' => 'Start Time' }],
                      values:  [{ 'field' => "kpi:#{Kpi.impressions.id}", 'label' => 'Impressions',
                                  'aggregate' => 'sum' }]
      )
      # With no filtering
      expect(report.fetch_page).to eql [
        { 'event_start_date' => '2014/01/01', 'values' => [100.00] },
        { 'event_start_date' => '2014/01/12', 'values' => [200.00] }
      ]

      # With filtering
      report.filter_params = { 'event:start_time' => { 'start' => '12:00 AM', 'end' => '02:00 AM' } }
      expect(report.fetch_page).to eql [
        { 'event_start_date' => '2014/01/12', 'values' => [200.00] }
      ]

      report.filter_params = { 'event:start_time' => { 'start' => '12:00 AM', 'end' => '' } }
      expect(report.fetch_page).to eql [
        { 'event_start_date' => '2014/01/01', 'values' => [100.00] },
        { 'event_start_date' => '2014/01/12', 'values' => [200.00] }
      ]

      report.filter_params = { 'event:start_time' => { 'start' => '12:00 AM', 'end' => nil } }
      expect(report.fetch_page).to eql [
        { 'event_start_date' => '2014/01/01', 'values' => [100.00] },
        { 'event_start_date' => '2014/01/12', 'values' => [200.00] }
      ]

      report.filter_params = { 'event:start_time' => { 'start' => nil, 'end' => nil } }
      expect(report.fetch_page).to eql [
        { 'event_start_date' => '2014/01/01', 'values' => [100.00] },
        { 'event_start_date' => '2014/01/12', 'values' => [200.00] }
      ]

      report.filter_params = { 'event:start_time' => { 'start' => nil, 'end' => '11:30 PM' } }
      expect(report.fetch_page).to eql [
        { 'event_start_date' => '2014/01/01', 'values' => [100.00] },
        { 'event_start_date' => '2014/01/12', 'values' => [200.00] }
      ]

      report.filter_params = { 'event:start_time' => { 'start' => '12:00 AM', 'end' => '11:30 PM' } }
      expect(report.fetch_page).to eql [
        { 'event_start_date' => '2014/01/01', 'values' => [100.00] },
        { 'event_start_date' => '2014/01/12', 'values' => [200.00] }
      ]
    end

    it 'can filter results by event status' do
      Timecop.travel Date.new(2014, 05, 05) do
        campaign.assign_all_global_kpis

        create(:late_event, start_date: '01/01/2014', start_time: '10:00 AM',
          end_date: '01/01/2014', end_time: '11:00 AM', campaign: campaign,
          results: { impressions: 100, interactions: 50 })

        create(:approved_event, start_date: '05/05/2014', start_time: '10:00 AM',
          end_date: '05/05/2014', end_time: '11:00 AM', campaign: campaign,
          results: { impressions: 300, interactions: 50 })

        create(:due_event, start_date: '05/04/2014', start_time: '10:00 AM',
          end_date: '05/04/2014', end_time: '11:00 AM', campaign: campaign,
          results: { impressions: 200, interactions: 150 })

        report = create(:report,
                        company: company,
                        columns: [{ 'field' => 'values', 'label' => 'Values' }],
                        rows:    [{ 'field' => 'event:start_date', 'label' => 'Start date' }],
                        filters: [{ 'field' => 'event:event_status', 'label' => 'Event Status' }],
                        values:  [{ 'field' => "kpi:#{Kpi.impressions.id}", 'label' => 'Impressions',
                                    'aggregate' => 'sum' }]
        )
        # With no filtering
        expect(report.fetch_page).to eql [
          { 'event_start_date' => '2014/01/01', 'values' => [100.00] },
          { 'event_start_date' => '2014/05/04', 'values' => [200.00] },
          { 'event_start_date' => '2014/05/05', 'values' => [300.00] }
        ]

        # filtering by late events
        report.filter_params = { 'event:event_status' => ['late'] }
        expect(report.fetch_page).to eql [
          { 'event_start_date' => '2014/01/01', 'values' => [100.00] }
        ]

        # filtering by due events
        report.filter_params = { 'event:event_status' => ['due'] }
        expect(report.fetch_page).to eql [
          { 'event_start_date' => '2014/05/04', 'values' => [200.00] }
        ]

        # filtering by approved events
        report.filter_params = { 'event:event_status' => ['approved'] }
        expect(report.fetch_page).to eql [
          { 'event_start_date' => '2014/05/05', 'values' => [300.00] }
        ]

        # filtering by late, due and approved events
        report.filter_params = { 'event:event_status' => %w(approved late due) }
        expect(report.fetch_page).to eql [
          { 'event_start_date' => '2014/01/01', 'values' => [100.00] },
          { 'event_start_date' => '2014/05/04', 'values' => [200.00] },
          { 'event_start_date' => '2014/05/05', 'values' => [300.00] }
        ]
      end
    end

    it 'can filter results by start/end times using timezone support' do
      company.timezone_support = true
      Company.current = company

      campaign.assign_all_global_kpis
      kpi = create(:kpi, company: company, kpi_type: 'number')
      campaign.add_kpi kpi
      event1 = create(:event, start_date: '01/01/2014', start_time: '10:00 AM',
        end_date: '01/01/2014', end_time: '11:00 AM', campaign: campaign,
        results: { impressions: 100, interactions: 50 })
      event1.result_for_kpi(kpi).value = 200
      event1.save

      create(:event, start_date: '01/12/2014', start_time: '01:00 AM',
        end_date: '01/12/2014', end_time: '03:00 AM', campaign: campaign,
        results: { impressions: 200, interactions: 150 })

      report = create(:report,
                      company: company,
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'event:start_date', 'label' => 'Start date' }],
                      filters: [{ 'field' => 'event:start_time', 'label' => 'Start Time' }],
                      values:  [{ 'field' => "kpi:#{Kpi.impressions.id}", 'label' => 'Impressions',
                                  'aggregate' => 'sum' }]
      )
      # With no filtering
      expect(report.fetch_page).to eql [
        { 'event_start_date' => '2014/01/01', 'values' => [100.00] },
        { 'event_start_date' => '2014/01/12', 'values' => [200.00] }
      ]

      # With filtering
      report.filter_params = { 'event:start_time' => { 'start' => '12:00 AM', 'end' => '02:00 AM' } }
      expect(report.fetch_page).to eql [
        { 'event_start_date' => '2014/01/12', 'values' => [200.00] }
      ]

      report.filter_params = { 'event:start_time' => { 'start' => '12:00 AM', 'end' => '' } }
      expect(report.fetch_page).to eql [
        { 'event_start_date' => '2014/01/01', 'values' => [100.00] },
        { 'event_start_date' => '2014/01/12', 'values' => [200.00] }
      ]

      report.filter_params = { 'event:start_time' => { 'start' => '12:00 AM', 'end' => nil } }
      expect(report.fetch_page).to eql [
        { 'event_start_date' => '2014/01/01', 'values' => [100.00] },
        { 'event_start_date' => '2014/01/12', 'values' => [200.00] }
      ]

      report.filter_params = { 'event:start_time' => { 'start' => nil, 'end' => nil } }
      expect(report.fetch_page).to eql [
        { 'event_start_date' => '2014/01/01', 'values' => [100.00] },
        { 'event_start_date' => '2014/01/12', 'values' => [200.00] }
      ]

      report.filter_params = { 'event:start_time' => { 'start' => nil, 'end' => '11:30 PM' } }
      expect(report.fetch_page).to eql [
        { 'event_start_date' => '2014/01/01', 'values' => [100.00] },
        { 'event_start_date' => '2014/01/12', 'values' => [200.00] }
      ]

      report.filter_params = { 'event:start_time' => { 'start' => '12:00 AM', 'end' => '11:30 PM' } }
      expect(report.fetch_page).to eql [
        { 'event_start_date' => '2014/01/01', 'values' => [100.00] },
        { 'event_start_date' => '2014/01/12', 'values' => [200.00] }
      ]
    end

    it 'can filter results by selected kpi segments' do
      campaign.assign_all_global_kpis
      kpi = create(:kpi, company: company, kpi_type: 'count')
      seg1 = create(:kpis_segment, kpi: kpi)
      seg2 = create(:kpis_segment, kpi: kpi)
      campaign.add_kpi kpi
      event1 = create(:event, start_date: '01/01/2014', end_date: '01/01/2014', campaign: campaign,
        results: { impressions: 100, interactions: 50 })
      event1.result_for_kpi(kpi).value = seg1.id
      expect(event1.save).to be_truthy

      event2 = create(:event, start_date: '01/12/2014', end_date: '01/12/2014', campaign: campaign,
        results: { impressions: 200, interactions: 150 })
      event2.result_for_kpi(kpi).value = seg2.id
      expect(event2.save).to be_truthy

      report = create(:report,
                      company: company,
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'event:start_date', 'label' => 'Start date' }],
                      filters: [{ 'field' => "kpi:#{kpi.id}", 'label' => 'A Numeric Filter' }],
                      values:  [{ 'field' => "kpi:#{Kpi.impressions.id}", 'label' => 'Impressions',
                                  'aggregate' => 'sum' }]
      )
      # With no filtering
      expect(report.fetch_page).to eql [
        { 'event_start_date' => '2014/01/01', 'values' => [100.00] },
        { 'event_start_date' => '2014/01/12', 'values' => [200.00] }
      ]

      report.filter_params = { "kpi:#{kpi.id}" => [seg1.id.to_s] }
      expect(report.fetch_page).to eql [
        { 'event_start_date' => '2014/01/01', 'values' => [100.00] }
      ]

      report.filter_params = { "kpi:#{kpi.id}" => [seg1.id.to_s, seg2.id.to_s] }
      expect(report.fetch_page).to eql [
        { 'event_start_date' => '2014/01/01', 'values' => [100.00] },
        { 'event_start_date' => '2014/01/12', 'values' => [200.00] }
      ]
    end

    it 'can filter by event active state' do
      # Events on campaing
      create(:event, campaign: campaign, active: false, results: { impressions: 100, interactions: 50 })
      create(:event, campaign: campaign, active: false, results: { impressions: 300, interactions: 300 })

      # Events on other campaing
      campaign2 = create(:campaign, name: 'Zeta 2014', company: company)
      campaign2.assign_all_global_kpis
      create(:event, campaign: campaign2, results: { impressions: 100, interactions: 50 })
      create(:event, campaign: campaign2, results: { impressions: 200, interactions: 100 })
      create(:event, campaign: campaign2, results: { impressions: 300, interactions: 300 })

      report = create(:report,
                      company: company,
                      filters: [{ 'field' => 'event:event_active', 'label' => 'Active State' }],
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'campaign:name', 'label' => 'Campaign' }],
                      values:  [{ 'field' => "kpi:#{Kpi.impressions.id}", 'label' => 'Impressions',
                                  'aggregate' => 'sum' }]
      )
      page = report.fetch_page
      expect(page).to eql [
        { 'campaign_name' => campaign.name, 'values' => [400.00] },
        { 'campaign_name' => campaign2.name, 'values' => [600.00] }
      ]

      # with filter
      report = create(:report,
                      company: company,
                      filters: [{ 'field' => 'event:event_active', 'label' => 'Active State' }],
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'campaign:name', 'label' => 'Campaign' }],
                      values:  [{ 'field' => "kpi:#{Kpi.impressions.id}", 'label' => 'Impressions',
                                  'aggregate' => 'sum' }]
      )
      report.filter_params = { 'event:event_active' => ['true'] }

      page = report.fetch_page
      expect(page).to eql [
        { 'campaign_name' => campaign2.name, 'values' => [600.00] }
      ]
    end

    it 'can filter by number of events' do
      # Events on campaing
      create(:event, campaign: campaign, results: { impressions: 100, interactions: 50 })
      create(:event, campaign: campaign, results: { impressions: 300, interactions: 300 })

      # Events on other campaing
      campaign2 = create(:campaign, name: 'Zeta 2014', company: company)
      campaign2.assign_all_global_kpis
      create(:event, campaign: campaign2, results: { impressions: 100, interactions: 50 })
      create(:event, campaign: campaign2, results: { impressions: 200, interactions: 100 })
      create(:event, campaign: campaign2, results: { impressions: 300, interactions: 300 })

      report = create(:report,
                      company: company,
                      filters: [{ 'field' => "kpi:#{Kpi.events.id}", 'label' => 'Events' }],
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'campaign:name', 'label' => 'Campaign' }],
                      values:  [{ 'field' => "kpi:#{Kpi.impressions.id}", 'label' => 'Impressions',
                                  'aggregate' => 'sum' }]
      )
      page = report.fetch_page
      expect(page).to eql [
        { 'campaign_name' => campaign.name, 'values' => [400.00] },
        { 'campaign_name' => campaign2.name, 'values' => [600.00] }
      ]

      # with filter
      report = create(:report,
                      company: company,
                      filters: [{ 'field' => "kpi:#{Kpi.events.id}", 'label' => 'Events' }],
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'campaign:name', 'label' => 'Campaign' }],
                      values:  [{ 'field' => "kpi:#{Kpi.impressions.id}", 'label' => 'Impressions',
                                  'aggregate' => 'sum' }]
      )
      report.filter_params = { "kpi:#{Kpi.events.id}" => { 'min' => '1', 'max' => '2' } }

      page = report.fetch_page
      expect(page).to eql [
        { 'campaign_name' => campaign.name, 'values' => [400.00] }
      ]
    end

    it 'can be filtered by promo hours' do
      # Events on campaing
      create(:event, campaign: campaign, results: { impressions: 100, interactions: 50 })
      create(:event, campaign: campaign, results: { impressions: 300, interactions: 300 })

      # Events on other campaing
      campaign2 = create(:campaign, name: 'Zeta 2014', company: company)
      campaign2.assign_all_global_kpis
      create(:event, campaign: campaign2, results: { impressions: 100, interactions: 50 })
      create(:event, campaign: campaign2, results: { impressions: 200, interactions: 100 })
      create(:event, campaign: campaign2, results: { impressions: 300, interactions: 300 })

      report = create(:report,
                      company: company,
                      filters: [{ 'field' => "kpi:#{Kpi.promo_hours.id}", 'label' => 'Promo Hours' }],
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'campaign:name', 'label' => 'Campaign' }],
                      values:  [{ 'field' => "kpi:#{Kpi.impressions.id}", 'label' => 'Impressions',
                                  'aggregate' => 'sum' }]
      )
      page = report.fetch_page
      expect(page).to eql [
        { 'campaign_name' => campaign.name, 'values' => [400.00] },
        { 'campaign_name' => campaign2.name, 'values' => [600.00] }
      ]

      # with filter
      report = create(:report,
                      company: company,
                      filters: [{ 'field' => "kpi:#{Kpi.promo_hours.id}", 'label' => 'Promo Hours' }],
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'campaign:name', 'label' => 'Campaign' }],
                      values:  [{ 'field' => "kpi:#{Kpi.impressions.id}", 'label' => 'Impressions',
                                  'aggregate' => 'sum' }]
      )
      report.filter_params = { "kpi:#{Kpi.promo_hours.id}" => { 'min' => '1', 'max' => '4' } }

      page = report.fetch_page
      expect(page).to eql [
        { 'campaign_name' => campaign.name, 'values' => [400.00] }
      ]
    end

    it 'can be filtered by event active state' do
      # Events on campaing
      create(:event, campaign: campaign, results: { impressions: 100, interactions: 50 })
      create(:event, campaign: campaign, results: { impressions: 300, interactions: 300 })

      # Events on other campaing
      campaign2 = create(:campaign, name: 'Zeta 2014', company: company)
      campaign2.assign_all_global_kpis
      create(:event, campaign: campaign2, results: { impressions: 100, interactions: 50 })
      create(:event, campaign: campaign2, results: { impressions: 200, interactions: 100 })
      create(:event, campaign: campaign2, results: { impressions: 300, interactions: 300 })

      report = create(:report,
                      company: company,
                      filters: [{ 'field' => "kpi:#{Kpi.promo_hours.id}", 'label' => 'Promo Hours' }],
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'campaign:name', 'label' => 'Campaign' }],
                      values:  [{ 'field' => "kpi:#{Kpi.impressions.id}", 'label' => 'Impressions',
                                  'aggregate' => 'sum' }]
      )
      page = report.fetch_page
      expect(page).to eql [
        { 'campaign_name' => campaign.name, 'values' => [400.00] },
        { 'campaign_name' => campaign2.name, 'values' => [600.00] }
      ]

      # with filter
      report = create(:report,
                      company: company,
                      filters: [{ 'field' => "kpi:#{Kpi.promo_hours.id}", 'label' => 'Promo Hours' }],
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'campaign:name', 'label' => 'Campaign' }],
                      values:  [{ 'field' => "kpi:#{Kpi.impressions.id}", 'label' => 'Impressions',
                                  'aggregate' => 'sum' }]
      )
      report.filter_params = { "kpi:#{Kpi.promo_hours.id}" => { 'min' => '1', 'max' => '4' } }

      page = report.fetch_page
      expect(page).to eql [
        { 'campaign_name' => campaign.name, 'values' => [400.00] }
      ]
    end

    it 'can be filtered by number of comments' do
      # Events on campaing
      event = create(:event, campaign: campaign, results: { impressions: 100, interactions: 50 })
      create_list(:comment, 2, commentable: event)
      event = create(:event, campaign: campaign, results: { impressions: 300, interactions: 300 })
      create_list(:comment, 2, commentable: event)

      # Events on other campaing
      campaign2 = create(:campaign, name: 'Zeta 2014', company: company)
      campaign2.assign_all_global_kpis
      create(:event, campaign: campaign2, results: { impressions: 100, interactions: 50 })
      create(:event, campaign: campaign2, results: { impressions: 200, interactions: 100 })
      create(:event, campaign: campaign2, results: { impressions: 300, interactions: 300 })

      report = create(:report,
                      company: company,
                      filters: [{ 'field' => "kpi:#{Kpi.comments.id}", 'label' => 'Comments' }],
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'campaign:name', 'label' => 'Campaign' }],
                      values:  [{ 'field' => "kpi:#{Kpi.impressions.id}", 'label' => 'Impressions',
                                  'aggregate' => 'sum' }]
      )
      page = report.fetch_page
      expect(page).to eql [
        { 'campaign_name' => campaign.name, 'values' => [400.00] },
        { 'campaign_name' => campaign2.name, 'values' => [600.00] }
      ]

      # with filter
      report = create(:report,
                      company: company,
                      filters: [{ 'field' => "kpi:#{Kpi.comments.id}", 'label' => 'Comments' }],
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'campaign:name', 'label' => 'Campaign' }],
                      values:  [{ 'field' => "kpi:#{Kpi.impressions.id}", 'label' => 'Impressions',
                                  'aggregate' => 'sum' }]
      )
      report.filter_params = { "kpi:#{Kpi.comments.id}" => { 'min' => '1', 'max' => '4' } }

      page = report.fetch_page
      expect(page).to eql [
        { 'campaign_name' => campaign.name, 'values' => [400.00] }
      ]
    end

    it 'can be filtered by number of photos' do
      # Events on campaing
      event = create(:event, campaign: campaign, results: { impressions: 100, interactions: 50 })
      create_list(:attached_asset, 2, attachable: event, asset_type: 'photo')
      event = create(:event, campaign: campaign, results: { impressions: 300, interactions: 300 })
      create_list(:attached_asset, 2, attachable: event, asset_type: 'photo')

      # Events on other campaing
      campaign2 = create(:campaign, name: 'Zeta 2014', company: company)
      campaign2.assign_all_global_kpis
      create(:event, campaign: campaign2, results: { impressions: 100, interactions: 50 })
      create(:event, campaign: campaign2, results: { impressions: 200, interactions: 100 })
      create(:event, campaign: campaign2, results: { impressions: 300, interactions: 300 })

      report = create(:report,
                      company: company,
                      filters: [{ 'field' => "kpi:#{Kpi.photos.id}", 'label' => 'Photos' }],
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'campaign:name', 'label' => 'Campaign' }],
                      values:  [{ 'field' => "kpi:#{Kpi.impressions.id}", 'label' => 'Impressions',
                                  'aggregate' => 'sum' }]
      )
      page = report.fetch_page
      expect(page).to eql [
        { 'campaign_name' => campaign.name, 'values' => [400.00] },
        { 'campaign_name' => campaign2.name, 'values' => [600.00] }
      ]

      # with filter
      report = create(:report,
                      company: company,
                      filters: [{ 'field' => "kpi:#{Kpi.photos.id}", 'label' => 'Photos' }],
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'campaign:name', 'label' => 'Campaign' }],
                      values:  [{ 'field' => "kpi:#{Kpi.impressions.id}", 'label' => 'Impressions',
                                  'aggregate' => 'sum' }]
      )
      report.filter_params = { "kpi:#{Kpi.photos.id}" => { 'min' => '1', 'max' => '4' } }

      page = report.fetch_page
      expect(page).to eql [
        { 'campaign_name' => campaign.name, 'values' => [400.00] }
      ]
    end

    it 'can be filtered by amount of expenses' do
      # Events on campaing
      event = create(:event, campaign: campaign, results: { impressions: 100, interactions: 50 })
      create(:event_expense, amount: 100, event: event)
      event = create(:event, campaign: campaign, results: { impressions: 300, interactions: 300 })
      create(:event_expense, amount: 200, event: event)

      # Events on other campaing
      campaign2 = create(:campaign, name: 'Zeta 2014', company: company)
      campaign2.assign_all_global_kpis
      event = create(:event, campaign: campaign2, results: { impressions: 100, interactions: 50 })
      create(:event_expense, amount: 1000, event: event)
      create(:event, campaign: campaign2, results: { impressions: 200, interactions: 100 })
      create(:event, campaign: campaign2, results: { impressions: 300, interactions: 300 })

      report = create(:report,
                      company: company,
                      filters: [{ 'field' => "kpi:#{Kpi.expenses.id}", 'label' => 'Comments' }],
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'campaign:name', 'label' => 'Campaign' }],
                      values:  [{ 'field' => "kpi:#{Kpi.impressions.id}", 'label' => 'Impressions',
                                  'aggregate' => 'sum' }]
      )
      page = report.fetch_page
      expect(page).to eql [
        { 'campaign_name' => campaign.name, 'values' => [400.00] },
        { 'campaign_name' => campaign2.name, 'values' => [600.00] }
      ]

      # with filter
      report = create(:report,
                      company: company,
                      filters: [{ 'field' => "kpi:#{Kpi.expenses.id}", 'label' => 'Comments' }],
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'campaign:name', 'label' => 'Campaign' }],
                      values:  [{ 'field' => "kpi:#{Kpi.impressions.id}", 'label' => 'Impressions',
                                  'aggregate' => 'sum' }]
      )
      report.filter_params = { "kpi:#{Kpi.expenses.id}" => { 'min' => '1', 'max' => '300' } }

      page = report.fetch_page
      expect(page).to eql [
        { 'campaign_name' => campaign.name, 'values' => [400.00] }
      ]

      report.filter_params = { "kpi:#{Kpi.expenses.id}" => { 'min' => '1', 'max' => '1300' } }
      page = report.fetch_page
      expect(page).to eql [
        { 'campaign_name' => campaign.name, 'values' => [400.00] },
        { 'campaign_name' => 'Zeta 2014', 'values' => [100.0] }
      ]
    end

    it 'can filter results by brands' do
      campaign.assign_all_global_kpis
      brand1 = create(:brand, name: 'Brand1')
      brand2 = create(:brand, name: 'Brand2')
      brand_portfolio1 = create(:brand_portfolio, name: 'BP1', company: company)
      brand_portfolio1.brands << brand1

      create(:event, start_date: '01/01/2014', end_date: '01/01/2014', campaign: campaign,
        results: { impressions: 100, interactions: 50 })

      campaign2 = create(:campaign, company: company)
      create(:event, start_date: '01/12/2014', end_date: '01/12/2014', campaign: campaign2,
        results: { impressions: 200, interactions: 150 })

      campaign3 = create(:campaign, company: company)
      create(:event, start_date: '01/13/2014', end_date: '01/13/2014', campaign: campaign3,
        results: { impressions: 300, interactions: 175 })

      # Campaign without brands or brand portfolios
      campaign4 = create(:campaign, company: company)
      create(:event, start_date: '01/15/2014', end_date: '01/15/2014', campaign: campaign4,
        results: { impressions: 350, interactions: 250 })

      # Make both campaigns to be related to the same brand
      campaign.brands << brand1
      campaign2.brand_portfolios << brand_portfolio1
      campaign3.brands << brand2
      campaign2.brands << brand2

      report = create(:report,
                      company: company,
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'event:start_date', 'label' => 'Start date' }],
                      filters: [{ 'field' => 'brand:name', 'label' => 'Brand' }],
                      values:  [{ 'field' => "kpi:#{Kpi.impressions.id}", 'label' => 'Impressions',
                                  'aggregate' => 'sum' }]
      )
      # With no filtering
      expect(report.fetch_page).to eql [
        { 'event_start_date' => '2014/01/01', 'values' => [100.00] },
        { 'event_start_date' => '2014/01/12', 'values' => [200.00] },
        { 'event_start_date' => '2014/01/13', 'values' => [300.00] },
        { 'event_start_date' => '2014/01/15', 'values' => [350.00] }
      ]

      report.filter_params = { 'brand:name' => ['Brand1'] }
      expect(report.fetch_page).to eql [
        { 'event_start_date' => '2014/01/01', 'values' => [100.00] },
        { 'event_start_date' => '2014/01/12', 'values' => [200.00] }
      ]

      report.filter_params = { 'brand:name' => ['Brand2'] }
      expect(report.fetch_page).to eql [
        { 'event_start_date' => '2014/01/12', 'values' => [200.00] },
        { 'event_start_date' => '2014/01/13', 'values' => [300.0] }
      ]

      report.filter_params = { 'brand:name' => %w(Brand1 Brand2) }
      expect(report.fetch_page).to eql [
        { 'event_start_date' => '2014/01/01', 'values' => [100.00] },
        { 'event_start_date' => '2014/01/12', 'values' => [200.00] },
        { 'event_start_date' => '2014/01/13', 'values' => [300.00] }
      ]
    end

    it 'can filter results by brand portfolios' do
      campaign.assign_all_global_kpis
      brand_portfolio1 = create(:brand_portfolio, name: 'BP1', company: company)
      brand_portfolio2 = create(:brand_portfolio, name: 'BP2', company: company)
      brand = create(:brand)
      brand_portfolio1.brands << brand
      brand_portfolio2.brands << brand

      create(:event, start_date: '01/01/2014', end_date: '01/01/2014', campaign: campaign,
        results: { impressions: 100, interactions: 50 })

      campaign2 = create(:campaign, company: company)
      create(:event, start_date: '01/12/2014', end_date: '01/12/2014', campaign: campaign2,
        results: { impressions: 200, interactions: 150 })

      campaign3 = create(:campaign, company: company)
      create(:event, start_date: '01/13/2014', end_date: '01/13/2014', campaign: campaign3,
        results: { impressions: 300, interactions: 175 })

      # Campaign without brands or brand portfolios
      campaign4 = create(:campaign, company: company)
      create(:event, start_date: '01/15/2014', end_date: '01/15/2014', campaign: campaign4,
        results: { impressions: 350, interactions: 250 })

      # Make both campaigns to be related to the same brand
      campaign.brand_portfolios << brand_portfolio1
      campaign2.brands << brand
      campaign3.brand_portfolios << brand_portfolio2
      campaign2.brand_portfolios << brand_portfolio2

      report = create(:report,
                      company: company,
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'event:start_date', 'label' => 'Start date' }],
                      filters: [{ 'field' => 'brand_portfolio:name', 'label' => 'Brand Portfolio' }],
                      values:  [{ 'field' => "kpi:#{Kpi.impressions.id}",
                                  'label' => 'Impressions', 'aggregate' => 'sum' }]
      )
      # With no filtering
      expect(report.fetch_page).to eql [
        { 'event_start_date' => '2014/01/01', 'values' => [100.00] },
        { 'event_start_date' => '2014/01/12', 'values' => [200.00] },
        { 'event_start_date' => '2014/01/13', 'values' => [300.00] },
        { 'event_start_date' => '2014/01/15', 'values' => [350.00] }
      ]

      report.filter_params = { 'brand_portfolio:name' => ['BP1'] }
      expect(report.fetch_page).to eql [
        { 'event_start_date' => '2014/01/01', 'values' => [100.00] },
        { 'event_start_date' => '2014/01/12', 'values' => [200.00] }
      ]

      report.filter_params = { 'brand_portfolio:name' => %w(BP1 BP2) }
      expect(report.fetch_page).to eql [
        { 'event_start_date' => '2014/01/01', 'values' => [100.00] },
        { 'event_start_date' => '2014/01/12', 'values' => [200.00] },
        { 'event_start_date' => '2014/01/13', 'values' => [300.00] }
      ]
    end

    it 'can filter results by a range of dates' do
      campaign.assign_all_global_kpis
      kpi = create(:kpi, company: company, kpi_type: 'count')
      seg1 = create(:kpis_segment, kpi: kpi)
      seg2 = create(:kpis_segment, kpi: kpi)
      campaign.add_kpi kpi
      event1 = create(:event, start_date: '01/01/2014', end_date: '01/01/2014', campaign: campaign,
        results: { impressions: 100, interactions: 50 })
      event1.result_for_kpi(kpi).value = seg1.id
      event1.save

      event2 = create(:event, start_date: '01/12/2014', end_date: '01/12/2014', campaign: campaign,
        results: { impressions: 200, interactions: 150 })
      event2.result_for_kpi(kpi).value = seg2.id
      event2.save

      report = create(:report,
                      company: company,
                      columns: [{ 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'event:start_date', 'label' => 'Start date' }],
                      filters: [{ 'field' => 'event:start_date', 'label' => 'Start Date' }],
                      values:  [{ 'field' => "kpi:#{Kpi.impressions.id}", 'label' => 'Impressions',
                                  'aggregate' => 'sum' }]
      )
      # With no filtering
      expect(report.fetch_page).to eql [
        { 'event_start_date' => '2014/01/01', 'values' => [100.00] },
        { 'event_start_date' => '2014/01/12', 'values' => [200.00] }
      ]

      report.filter_params = { 'event:start_date' => { 'start' => '01/01/2014', 'end' => '01/01/2014' } }
      expect(report.fetch_page).to eql [
        { 'event_start_date' => '2014/01/01', 'values' => [100.00] }
      ]

      report.filter_params = { 'event:start_date' => { 'start' => '01/01/2014', 'end' => '01/12/2014' } }
      expect(report.fetch_page).to eql [
        { 'event_start_date' => '2014/01/01', 'values' => [100.00] },
        { 'event_start_date' => '2014/01/12', 'values' => [200.00] }
      ]
    end
  end

  describe '#first_row_values_for_page' do
    let(:company) { create(:company) }
    let(:campaign) { create(:campaign, name: 'Guaro Cacique 2013', company: company) }
    before do
      Kpi.create_global_kpis
    end
    it 'returns all the venues names' do
      create(:event, campaign: campaign, place: create(:place, state: 'Texas', city: 'Houston'),
        results: { impressions: 100 })
      create(:event, campaign: campaign, place: create(:place, state: 'California', city: 'Los Angeles'),
        results: { impressions: 200 })
      create(:event, place: create(:place, state: 'California', city: 'San Francisco'),
                     campaign: create(:campaign, name: 'Ron Centenario FY12', company: company),
                     results: { impressions: 300 })
      report = create(:report,
                      company: company,
                      columns: [{ 'field' => 'place:state', 'label' => 'State' }, { 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'campaign:name', 'label' => 'Campaign' }],
                      values:  [{ 'field' => "kpi:#{Kpi.impressions.id}", 'label' => 'Impressions', 'aggregate' => 'sum' }]
      )
      values = report.first_row_values_for_page
      expect(values).to match_array ['Guaro Cacique 2013', 'Ron Centenario FY12']

      # Test to_csv
      csv = CSV.parse(report.to_csv)
      expect(csv[0]).to eql ['Campaign', 'California/Impressions', 'Texas/Impressions']
      expect(csv[1]).to eql ['Guaro Cacique 2013', '200.00', '100.00']
      expect(csv[2]).to eql ['Ron Centenario FY12', '300.00', nil]
    end

    it 'returns all the campaign names' do
      create(:event, campaign: campaign,
                     place: create(:place, name: 'Bar Texano', state: 'Texas', city: 'Houston'),
                     results: { impressions: 100 })
      create(:event, campaign: campaign,
                     place: create(:place, name: 'Texas Restaurant', state: 'California', city: 'Los Angeles'),
                     results: { impressions: 200 })
      create(:event, campaign: campaign,
                     place: create(:place, name: 'Texas Bar & Grill', state: 'California', city: 'San Francisco'),
                     results: { impressions: 300 })
      report = create(:report,
                      company: company,
                      columns: [{ 'field' => 'campaign:name', 'label' => 'State' }, { 'field' => 'values', 'label' => 'Values' }],
                      rows:    [{ 'field' => 'place:name', 'label' => 'Venue' }],
                      values:  [{ 'field' => "kpi:#{Kpi.impressions.id}", 'label' => 'Impressions', 'aggregate' => 'sum' }]
      )
      values = report.first_row_values_for_page
      expect(values).to match_array ['Bar Texano', 'Texas Bar & Grill', 'Texas Restaurant']

      # Test to_csv
      csv = CSV.parse(report.to_csv)
      expect(csv[0]).to eql ['Venue', 'Guaro Cacique 2013/Impressions']
      expect(csv[1]).to eql ['Bar Texano', '100.00']
      expect(csv[2]).to eql ['Texas Bar & Grill', '300.00']
      expect(csv[3]).to eql ['Texas Restaurant', '200.00']
    end
  end
end
