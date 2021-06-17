class CreateCustomActivityConditions < ActiveRecord::Migration
  def change
    create_table :custom_activity_conditions do |t|
      t.integer :sequence_id_acted_on
      t.integer :sequence_id_dependent_on
      t.integer :sequence_id_value_dependent_on
      t.string :condition
      t.string :action

      t.timestamps null: false
    end
    
    add_index :custom_activity_conditions, :sequence_id_acted_on, name: 'seq_acted'
    add_index :custom_activity_conditions, :sequence_id_dependent_on, name: 'seq_dep'
    add_index :custom_activity_conditions, :sequence_id_value_dependent_on, name: 'seq_value_dep'
  end
end
