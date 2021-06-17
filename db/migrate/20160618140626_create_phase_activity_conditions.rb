class CreatePhaseActivityConditions < ActiveRecord::Migration
  def change
    create_table :phase_activity_conditions do |t|
      t.integer :phase_activity_id, null: false
      t.integer :condition, null: false, default: 0
      t.integer :operator, null: false, default: 0
      t.integer :conditional_phase_activity_id, null: false

      t.timestamps null: false
    end

    add_index :phase_activity_conditions, :phase_activity_id, name: 'pac_phase_activity_id'
    add_index :phase_activity_conditions, :conditional_phase_activity_id, name: 'pac_conditional_phase_activity_id'
  end
end
