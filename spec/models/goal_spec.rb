# == Schema Information
#
# Table name: goals
#
#  id               :integer          not null, primary key
#  kpi_id           :integer
#  kpis_segment_id  :integer
#  value            :decimal(, )
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  goalable_id      :integer
#  goalable_type    :string(255)
#  parent_id        :integer
#  parent_type      :string(255)
#  title            :string(255)
#  start_date       :date
#  due_date         :date
#  activity_type_id :integer
#

require 'rails_helper'

describe Goal, type: :model do

  it { is_expected.to validate_presence_of(:goalable_id) }
  it { is_expected.to validate_presence_of(:goalable_type) }

  it { is_expected.to validate_numericality_of(:goalable_id) }
  it { is_expected.to validate_numericality_of(:kpi_id) }
  it { is_expected.to validate_numericality_of(:kpis_segment_id) }
  it { is_expected.to validate_numericality_of(:value) }

  it { is_expected.to belong_to(:goalable) }
  it { is_expected.to belong_to(:parent) }
  it { is_expected.to belong_to(:kpi) }
  it { is_expected.to belong_to(:kpis_segment) }

  context do
    before { subject.activity_type_id = 1 }
    it { is_expected.not_to validate_presence_of(:kpi_id) }
    it { is_expected.not_to validate_numericality_of(:kpi_id) }
  end

  context do
    before { subject.activity_type_id = nil }
    it { is_expected.to validate_presence_of(:kpi_id) }
    it { is_expected.to validate_numericality_of(:kpi_id) }
  end

  context do
    before { subject.kpi_id = 1 }
    it { is_expected.not_to validate_presence_of(:activity_type_id) }
    it { is_expected.not_to validate_numericality_of(:activity_type_id) }
  end

  context do
    before { subject.kpi_id = nil }
    it { is_expected.to validate_presence_of(:activity_type_id) }
    it { is_expected.to validate_numericality_of(:activity_type_id) }
  end

  describe 'due_date validation' do
    subject { described_class.new(start_date: '01/20/2016') }

    it { is_expected.not_to allow_value('01/19/2016').for(:due_date).with_message('must be a date on or after 01/20/2016') }
    it { is_expected.to allow_value('01/20/2016').for(:due_date) }
    it { is_expected.to allow_value('01/21/2016').for(:due_date) }
    it { is_expected.to allow_value(nil).for(:due_date) }
    it { is_expected.to allow_value('').for(:due_date) }
  end

  describe 'set_kpi_id' do
    it 'should set the kpi_id if nill and the kpis_segment_id is set' do
      segment = create(:kpis_segment, kpi: create(:kpi))
      goal = described_class.new(kpis_segment_id: segment.id)
      goal.valid?
      expect(goal.kpi_id).to eql segment.kpi_id
    end
  end
end
