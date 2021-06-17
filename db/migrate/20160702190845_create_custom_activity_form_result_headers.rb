class CreateCustomActivityFormResultHeaders < ActiveRecord::Migration
  def change
    create_table :custom_activity_form_result_headers do |t|
    	t.integer :event_id
    	t.integer :user_id
    	t.timestamps null: false

    end
    
    add_index :custom_activity_form_result_headers, :event_id, name: 'caf_result_event'
  end
end
