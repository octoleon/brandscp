class CreateCampaignCustomActivityForms < ActiveRecord::Migration
  def change
    create_table :campaign_custom_activity_forms do |t|
      t.integer :campaign_id
      t.integer :custom_activity_forms
      t.timestamps null: false
    end    
  end
end
