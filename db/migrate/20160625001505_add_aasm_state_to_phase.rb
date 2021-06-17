class AddAasmStateToPhase < ActiveRecord::Migration
  def change
  	add_column :phases, :aasm_state, :string
  end
end
