class CampaignCustomActivityForm < ActiveRecord::Base
  belongs_to :custom_activity_form
  belongs_to :campaign
	
  searchable do
  integer :campaign_id
  integer :custom_activity_form_id
  end
end
