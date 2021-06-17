class CreateCustomActivityKpiOperations < ActiveRecord::Migration
  def change
    create_table :custom_activity_kpi_operations do |t|
      t.integer :sequence_id_dependent_on
      t.integer :sequence_id_value_dependent_on
      t.integer :kpi_id_acted_on
      t.string :operation
      t.string :operationValue

      t.timestamps null: false
    end
    add_index :custom_activity_kpi_operations, :sequence_id_dependent_on, name: 'custom_activity_kpi_operations_seq_dep'
    add_index :custom_activity_kpi_operations, :sequence_id_value_dependent_on, name: 'custom_activity_kpi_operations_seq_value_dep'
  end
end
