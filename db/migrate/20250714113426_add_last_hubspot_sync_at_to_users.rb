class AddLastHubspotSyncAtToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :last_hubspot_sync_at, :datetime
  end
end
