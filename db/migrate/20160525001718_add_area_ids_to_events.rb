class AddAreaIdsToEvents < ActiveRecord::Migration
  def change
    add_column :events, :areas_ids, :integer, array: true, default: []
  end
end
