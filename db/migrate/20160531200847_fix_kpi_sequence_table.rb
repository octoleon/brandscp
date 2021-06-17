class FixKpiSequenceTable < ActiveRecord::Migration
  def change
    rename_column :custom_activity_kpi_operations, :sequence_id_dependent_on, :custom_activity_sequence_id
    rename_column :custom_activity_kpi_operations, :kpi_id_acted_on, :kpi_id
  end
end
