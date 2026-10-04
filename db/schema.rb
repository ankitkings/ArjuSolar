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

ActiveRecord::Schema[7.1].define(version: 2026_01_03_000000) do
  create_table "admin_users", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admin_users_on_email", unique: true
  end

  create_table "installations", force: :cascade do |t|
    t.integer "service_request_id", null: false
    t.date "installed_on", null: false
    t.decimal "capacity_kw", precision: 6, scale: 2, null: false
    t.integer "panel_count"
    t.string "panel_brand"
    t.string "inverter_model"
    t.text "site_address"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["service_request_id"], name: "index_installations_on_service_request_id", unique: true
  end

  create_table "maintenance_visits", force: :cascade do |t|
    t.integer "service_request_id", null: false
    t.integer "installation_id", null: false
    t.integer "team_member_id"
    t.string "title", null: false
    t.date "due_on", null: false
    t.string "status", default: "scheduled", null: false
    t.datetime "assigned_at"
    t.datetime "completed_at"
    t.text "report"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["installation_id"], name: "index_maintenance_visits_on_installation_id"
    t.index ["service_request_id"], name: "index_maintenance_visits_on_service_request_id"
    t.index ["status", "due_on"], name: "index_maintenance_visits_on_status_and_due_on"
    t.index ["team_member_id"], name: "index_maintenance_visits_on_team_member_id"
  end

  create_table "payments", force: :cascade do |t|
    t.integer "service_request_id", null: false
    t.integer "team_member_id"
    t.string "status", default: "pending", null: false
    t.decimal "amount", precision: 10, scale: 2
    t.date "received_on"
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["service_request_id"], name: "index_payments_on_service_request_id", unique: true
    t.index ["team_member_id"], name: "index_payments_on_team_member_id"
  end

  create_table "request_updates", force: :cascade do |t|
    t.integer "service_request_id", null: false
    t.integer "admin_user_id"
    t.string "status"
    t.integer "progress"
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "team_member_id"
    t.index ["admin_user_id"], name: "index_request_updates_on_admin_user_id"
    t.index ["service_request_id"], name: "index_request_updates_on_service_request_id"
    t.index ["team_member_id"], name: "index_request_updates_on_team_member_id"
  end

  create_table "service_requests", force: :cascade do |t|
    t.string "name", null: false
    t.string "phone", null: false
    t.string "email"
    t.string "ip_address"
    t.text "message"
    t.string "status", default: "pending", null: false
    t.integer "progress", default: 0, null: false
    t.integer "team_member_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_service_requests_on_status"
    t.index ["team_member_id"], name: "index_service_requests_on_team_member_id"
  end

  create_table "team_members", force: :cascade do |t|
    t.string "name", null: false
    t.string "department", null: false
    t.string "phone"
    t.text "bio"
    t.boolean "show_on_website", default: true, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "email"
    t.string "password_digest"
    t.index ["email"], name: "index_team_members_on_email", unique: true
  end

  create_table "visits", force: :cascade do |t|
    t.string "ip_address"
    t.string "user_agent"
    t.string "browser"
    t.string "os"
    t.string "device"
    t.string "path"
    t.string "referrer"
    t.datetime "visited_at", null: false
    t.index ["ip_address"], name: "index_visits_on_ip_address"
    t.index ["visited_at"], name: "index_visits_on_visited_at"
  end

  add_foreign_key "installations", "service_requests"
  add_foreign_key "maintenance_visits", "installations"
  add_foreign_key "maintenance_visits", "service_requests"
  add_foreign_key "maintenance_visits", "team_members"
  add_foreign_key "payments", "service_requests"
  add_foreign_key "payments", "team_members"
  add_foreign_key "request_updates", "admin_users"
  add_foreign_key "request_updates", "service_requests"
  add_foreign_key "request_updates", "team_members"
  add_foreign_key "service_requests", "team_members"
end
