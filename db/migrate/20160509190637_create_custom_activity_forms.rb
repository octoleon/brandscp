class CreateCustomActivityForms < ActiveRecord::Migration
  def change
    create_table :custom_activity_forms do |t|
      t.string :name
      t.string :description
      t.boolean :allowMultipleEntries
      t.boolean :showInQuickActions
      t.integer :company_id

      t.timestamps null: false
    end
    add_index :custom_activity_forms, :company_id
  end
end
