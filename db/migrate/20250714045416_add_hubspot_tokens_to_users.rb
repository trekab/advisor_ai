class AddHubspotTokensToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :hubspot_access_token, :string
    add_column :users, :hubspot_refresh_token, :string
  end
end
