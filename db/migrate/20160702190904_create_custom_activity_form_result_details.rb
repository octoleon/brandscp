class CreateCustomActivityFormResultDetails < ActiveRecord::Migration
  def change
    create_table :custom_activity_form_result_details do |t|
		t.integer :custom_activity_form_result_header_id
    	t.integer :form_field_id
    	t.string :result
    end
    
    add_index :custom_activity_form_result_details, :custom_activity_form_result_header_id, name: 'caf_result_header'
  end
end
