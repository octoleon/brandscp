class FixConditionalTableSequenceIdColumnName < ActiveRecord::Migration
  def change
    rename_column :custom_activity_conditions, :sequence_id_acted_on, :custom_activity_sequence_id
  end
end
