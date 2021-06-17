class AddDueDateToPhaseActivities < ActiveRecord::Migration
  def change
  	add_column :phase_activities, :due_date, :datetime
  end
end
