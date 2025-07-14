# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_07_14_113426) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

# Could not dump table "emails" because of following StandardError
#   Unknown type 'vector' for column 'embedding'


  create_table "instructions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.text "content"
    t.string "embedding"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_instructions_on_user_id"
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "role"
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_messages_on_user_id"
  end

  create_table "tasks", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "title"
    t.text "description"
    t.integer "status"
    t.integer "task_type"
    t.jsonb "progress"
    t.jsonb "steps"
    t.jsonb "result"
    t.text "error_message"
    t.datetime "completed_at"
    t.datetime "failed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_tasks_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email"
    t.string "google_access_token"
    t.string "google_refresh_token"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "hubspot_access_token"
    t.string "hubspot_refresh_token"
    t.datetime "hubspot_token_updated_at"
    t.datetime "last_email_sync_at"
    t.text "sync_error"
    t.datetime "last_hubspot_sync_at"
  end

  add_foreign_key "emails", "users"
  add_foreign_key "instructions", "users"
  add_foreign_key "messages", "users"
  add_foreign_key "tasks", "users"
end
