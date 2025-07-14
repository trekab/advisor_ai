class CreateInstructions < ActiveRecord::Migration[8.0]
  def change
    create_table :instructions do |t|
      t.references :user, null: false, foreign_key: true
      t.text :content
      t.string :embedding

      t.timestamps
    end
  end
end
