class AddLastEmailSyncAtToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :last_email_sync_at, :datetime
  end
end
