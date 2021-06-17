class AddColumnsToPhases < ActiveRecord::Migration
  def change
  	add_column :phases, :submitted_at, :datetime
  	add_column :phases, :approved_at, :datetime
  	add_column :phases, :rejected_at, :datetime
  end
end
