class CreatePhases < ActiveRecord::Migration
  def change
    create_table :phases do |t|
      t.string :name, null: false
      t.text :description
      t.boolean :requires_approval, default: false
      t.integer :campaign_id, null: false
      t.integer :order, null: false

      t.timestamps null: false
    end

    add_index :phases, :campaign_id, unique: false
  end
end
