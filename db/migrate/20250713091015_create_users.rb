class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :email
      t.string :google_access_token
      t.string :google_refresh_token

      t.timestamps
    end
  end
end
