class AddHubspotTokenUpdatedAtToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :hubspot_token_updated_at, :datetime
  end
end
