# == Schema Information
#
# Table name: entity_forms
#
#  id         :integer          not null, primary key
#  entity     :string(255)
#  entity_id  :integer
#  company_id :integer
#  created_at :datetime
#  updated_at :datetime
#

require 'rails_helper'

RSpec.describe EntityForm, type: :model do
  it { is_expected.to belong_to(:company) }
  it { is_expected.to have_many(:form_fields) }
  it { is_expected.to validate_uniqueness_of(:entity) }
end
