class AddColumnsToPhasesAndPhaseactivities < ActiveRecord::Migration
  def change
  	add_column :phases, :conditional_action, :integer, default: 0, null: false
  	add_column :phases, :conditional_status, :integer, default: 0, null: false
  	add_column :phase_activities, :conditional_action, :integer, default: 0, null: false
  	add_column :phase_activities, :conditional_status, :integer, default: 0, null: false
  end
end
