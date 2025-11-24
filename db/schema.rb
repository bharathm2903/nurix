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

ActiveRecord::Schema[7.1].define(version: 2025_11_23_172746) do
  create_table "comments", force: :cascade do |t|
    t.string "comment"
    t.integer "post_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["post_id"], name: "index_comments_on_post_id"
  end

  create_table "jobs", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "status", default: "pending", null: false
    t.json "payload", null: false
    t.string "idempotency_key"
    t.integer "retry_count", default: 0, null: false
    t.integer "max_retries", default: 3, null: false
    t.datetime "leased_at"
    t.string "leased_by"
    t.text "error_message"
    t.string "trace_id"
    t.datetime "started_at"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["idempotency_key"], name: "index_jobs_on_idempotency_key", unique: true
    t.index ["leased_at"], name: "index_jobs_on_leased_at"
    t.index ["status"], name: "index_jobs_on_status"
    t.index ["trace_id"], name: "index_jobs_on_trace_id"
    t.index ["user_id", "status"], name: "index_jobs_on_user_id_and_status"
    t.index ["user_id"], name: "index_jobs_on_user_id"
  end

  create_table "posts", force: :cascade do |t|
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_posts_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.integer "age"
    t.json "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "comments", "posts"
  add_foreign_key "jobs", "users"
  add_foreign_key "posts", "users"
end
