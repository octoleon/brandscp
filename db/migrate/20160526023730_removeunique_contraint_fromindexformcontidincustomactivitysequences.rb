class RemoveuniqueContraintFromindexformcontidincustomactivitysequences < ActiveRecord::Migration
  def change
    remove_index :custom_activity_sequences, name: 'form_cont_id'
    add_index :custom_activity_sequences, [:custom_activity_form_id,:context,:reference_id], unique: false, name: 'form_cont_id'
  end
end
