class ModifyCustomActivityFormResultHeader < ActiveRecord::Migration
  def change
  	add_column :custom_activity_form_result_headers, :complete, :bool
  	add_column :custom_activity_form_result_headers, :custom_activity_form_id, :integer  	
    add_index :custom_activity_form_result_headers, :custom_activity_form_id, name: 'custom_activity_form id_for_result_header'

  end
  
end
