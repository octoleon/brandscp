class FixColumnNameInCampaignCustomActivityForms < ActiveRecord::Migration
  def change
  	rename_column :campaign_custom_activity_forms, :custom_activity_forms, :custom_activity_form_id
  end
end
