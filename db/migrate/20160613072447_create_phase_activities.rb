class CreatePhaseActivities < ActiveRecord::Migration
  def change
    create_table :phase_activities do |t|
      t.integer :phase_id, null: false
      t.string :activity_type, null: false
      t.integer :activity_id, null: false
      t.integer :order, null: false
      t.string :display_name
      t.boolean :required, null: false, default: false
      t.text :settings

      t.timestamps null: false
    end

    add_index :phase_activities, [:phase_id, :activity_type, :activity_id], unique: true, name: 'phase_activities_unique_constraint'
  end
end
