class CreateEmails < ActiveRecord::Migration[8.0]
  def change
    create_table :emails do |t|
      t.references :user, null: false, foreign_key: true
      t.string :subject
      t.string :from
      t.string :to
      t.text :content
      t.string :message_id
      t.column :embedding, :vector, limit: 1536

      t.timestamps
    end
  end
end
