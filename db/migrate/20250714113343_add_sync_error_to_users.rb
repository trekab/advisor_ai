class AddSyncErrorToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :sync_error, :text
  end
end
