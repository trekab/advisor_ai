class CreateTasks < ActiveRecord::Migration[8.0]
  def change
    create_table :tasks do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title
      t.text :description
      t.integer :status
      t.integer :task_type
      t.jsonb :progress
      t.jsonb :steps
      t.jsonb :result
      t.text :error_message
      t.datetime :completed_at
      t.datetime :failed_at

      t.timestamps
    end
  end
end
