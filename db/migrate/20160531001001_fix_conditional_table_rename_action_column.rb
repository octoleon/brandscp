class FixConditionalTableRenameActionColumn < ActiveRecord::Migration
  def change
     rename_column :custom_activity_conditions, :action, :operator 
  end
end
