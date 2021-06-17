# == Schema Information
#
# Table name: data_extracts
#
#  id               :integer          not null, primary key
#  type             :string(255)
#  company_id       :integer
#  active           :boolean          default("true")
#  sharing          :string(255)
#  name             :string(255)
#  description      :text
#  columns          :text
#  created_by_id    :integer
#  updated_by_id    :integer
#  created_at       :datetime
#  updated_at       :datetime
#  default_sort_by  :string(255)
#  default_sort_dir :string(255)
#  params           :text
#

require 'rails_helper'

RSpec.describe DataExtract::ActivityType, type: :model do
  describe '#available_columns' do
    let(:subject) { described_class }

    it 'returns the correct columns' do
      expect(subject.exportable_columns).to eql([
        %w(name Name), %w(description Description), ['created_at', 'Created At'],
        ['created_by', 'Created By'], ['modified_at', 'Modified At'],
        ['modified_by', 'Modified By'], ['active_state', 'Active State']])
    end
  end

  describe '#rows' do
    let(:company) { create(:company) }
    let(:company_user) do
      create(:company_user, company: company,
                            user: create(:user, first_name: 'Benito', last_name: 'Camelas'))
    end
    let(:subject) do
      described_class.new(company: company, current_user: company_user,
                    columns: %w(name description created_by created_at active_state))
    end

    it 'returns empty if no rows are found' do
      expect(subject.rows).to be_empty
    end

    describe 'with data' do
      before do
        create(:activity_type, name: 'Activty Type Test1', active: true, created_by_id: company_user.user.id, company: company, created_at: Time.zone.local(2013, 8, 23, 9, 15))
      end

      it 'returns all the activity types in the company with all the columns' do
        expect(subject.rows).to eql [
          ['Activty Type Test1', 'Activity Type description', 'Benito Camelas', '08/23/2013', 'Active']
        ]
      end

      it 'allows to filter the results' do
        subject.filters = { 'status' => ['inactive'] }
        expect(subject.rows).to be_empty

        subject.filters = { 'status' => ['active'] }
        expect(subject.rows).to eql [
          ['Activty Type Test1', 'Activity Type description', 'Benito Camelas', '08/23/2013', 'Active']
        ]
      end

      it 'allows to sort the results' do
        create(:activity_type, name: 'Other Activity Type', active: true, created_by_id: company_user.user.id,
                company: company, created_at: Time.zone.local(2015, 2, 12, 9, 15))
        create(:activity_type, name: 'Activity Type 3', active: true, created_by_id: company_user.user.id,
                company: company, created_at: Time.zone.local(2014, 2, 12, 9, 15))

        subject.columns = %w(name created_at)
        subject.default_sort_by = 'name'
        subject.default_sort_dir = 'ASC'
        expect(subject.rows).to eql [
          ['Activity Type 3', '02/12/2014'],
          ['Activty Type Test1', '08/23/2013'],
          ['Other Activity Type', '02/12/2015']
        ]

        subject.default_sort_by = 'name'
        subject.default_sort_dir = 'DESC'
        expect(subject.rows).to eql [
          ['Other Activity Type', '02/12/2015'],
          ['Activty Type Test1', '08/23/2013'],
          ['Activity Type 3', '02/12/2014']
        ]

        subject.default_sort_by = 'created_at'
        subject.default_sort_dir = 'ASC'
        expect(subject.rows).to eql [
          ['Activty Type Test1', '08/23/2013'],
          ['Activity Type 3', '02/12/2014'],
          ['Other Activity Type', '02/12/2015']
        ]

        subject.default_sort_by = 'created_at'
        subject.default_sort_dir = 'DESC'
        expect(subject.rows).to eql [
          ['Other Activity Type', '02/12/2015'],
          ['Activity Type 3', '02/12/2014'],
          ['Activty Type Test1', '08/23/2013']
        ]
      end
    end
  end
end
