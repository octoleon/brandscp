class CreateCustomActivitySequences < ActiveRecord::Migration
  def change
    create_table :custom_activity_sequences do |t|
      t.integer :custom_activity_form_id
      t.integer :sequence
      t.string :context
      t.integer :minTimesMustBeAnswered
      t.integer :maxTimesMayBeAnswered
      t.integer :reference_id
      t.timestamps null: false
    end
    add_index :custom_activity_sequences, :custom_activity_form_id
    add_index :custom_activity_sequences, [:custom_activity_form_id,:sequence], name: 'form_seq'
    add_index :custom_activity_sequences, [:custom_activity_form_id,:context] , name: 'form_cont'
    add_index :custom_activity_sequences, [:custom_activity_form_id,:context,:sequence], name: 'form_cont_seq'
    add_index :custom_activity_sequences, [:custom_activity_form_id,:context,:reference_id], unique: true, name: 'form_cont_id'
  end
end
