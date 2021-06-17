class AddRemoteIdToInvites < ActiveRecord::Migration
  def change
    add_column :invite_individuals, :remote_id, :string
    add_index :invite_individuals, [:invite_id, :remote_id]
  end
end
