class AddEventsToAreasCampaign < ActiveRecord::Migration
  def change
    add_column :areas_campaigns, :events_ids, :integer, array: true, default: []
  end
end
