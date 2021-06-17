class CreatePhaseConditions < ActiveRecord::Migration
  def change
    create_table :phase_conditions do |t|
      t.integer :phase_id, null: false
      t.integer :condition, null: false, default: 0
      t.integer :operator, null: false, default: 0
      t.integer :conditional_phase_id, null: false

      t.timestamps null: false
    end

    add_index :phase_conditions, :phase_id
    add_index :phase_conditions, :conditional_phase_id
  end
end
