# frozen_string_literal: true

class AddMarginAndAttendance < ActiveRecord::Migration[7.1]
  def change
    # ---- parts: the actual price we pay + our margin = the selling price (unit_price) ----
    add_column :catalog_items, :cost_price, :decimal, precision: 10, scale: 2, null: false, default: 0
    add_column :catalog_items, :margin, :decimal, precision: 10, scale: 2, null: false, default: 0
    add_column :stock_orders, :unit_cost, :decimal, precision: 10, scale: 2 # actual price when the order was placed
    reversible do |dir|
      # selling prices stay exactly as they are; the actual price starts equal to them (margin 0) until it is entered
      dir.up { execute 'UPDATE catalog_items SET cost_price = unit_price, margin = 0' }
    end

    # ---- team: salary, attendance, leave ----
    add_column :team_members, :monthly_salary, :decimal, precision: 10, scale: 2

    create_table :attendances do |t|
      t.references :team_member, null: false, foreign_key: { on_delete: :cascade }
      t.date :date, null: false
      t.string :status, null: false, default: 'present'   # present / half_day / absent
      t.datetime :check_in_at
      t.datetime :check_out_at
      t.string :note
      t.string :marked_by, null: false, default: 'self'   # self / admin
      t.timestamps
    end
    add_index :attendances, %i[team_member_id date], unique: true
    add_index :attendances, :date

    create_table :leave_requests do |t|
      t.references :team_member, null: false, foreign_key: { on_delete: :cascade }
      t.string :kind, null: false, default: 'paid'        # paid / sick / unpaid
      t.date :from_date, null: false
      t.date :to_date, null: false
      t.text :reason
      t.string :status, null: false, default: 'pending'   # pending / approved / cancelled
      t.string :decided_by                                # admin / employee
      t.string :admin_note
      t.datetime :decided_at
      t.timestamps
    end
    add_index :leave_requests, :status

    create_table :attendance_settings do |t|
      t.decimal :half_day_hours, precision: 4, scale: 1, null: false, default: 4 # checked out earlier = half a day
      t.boolean :sunday_off, null: false, default: true
      t.timestamps
    end
  end
end
