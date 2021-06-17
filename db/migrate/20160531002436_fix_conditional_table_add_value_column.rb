class FixConditionalTableAddValueColumn < ActiveRecord::Migration
  def change
  	add_column :custom_activity_conditions, :value, :string
  end
end
