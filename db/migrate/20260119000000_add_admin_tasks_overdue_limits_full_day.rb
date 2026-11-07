class AddAdminTasksOverdueLimitsFullDay < ActiveRecord::Migration[7.1]
  def change
    # attendance: a full day = at least this many hours between check-in and check-out; less is a half day
    add_column :attendance_settings, :full_day_hours, :decimal, precision: 4, scale: 1, null: false, default: 8

    # admin "My tasks": when a request was handed to the admin, and when the admin last looked at the list
    add_column :service_requests, :admin_assigned_at, :datetime
    add_column :admin_users, :tasks_seen_at, :datetime
    reversible do |dir|
      dir.up { execute "UPDATE service_requests SET admin_assigned_at = updated_at WHERE assigned_to_admin = TRUE" }
    end

    # overdue days the admin has changed (anything not listed uses the standard days)
    create_table :overdue_limits do |t|
      t.string :key, null: false
      t.integer :days, null: false
      t.timestamps
    end
    add_index :overdue_limits, :key, unique: true
  end
end
