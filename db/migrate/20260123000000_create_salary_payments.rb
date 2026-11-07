# Safe to run again: it only creates what is missing.
class CreateSalaryPayments < ActiveRecord::Migration[7.1]
  def up
    return if table_exists?(:salary_payments)

    # one row = the salary of one employee for one month, as it was paid
    create_table :salary_payments do |t|
      t.references :team_member, foreign_key: { on_delete: :nullify }   # the record stays even if the employee is removed later
      t.string :member_name, null: false
      t.string :department
      t.date :month, null: false                       # first day of the month
      # the month as it was worked out when the salary was paid
      t.decimal :monthly_salary, precision: 10, scale: 2, null: false
      t.integer :working_days, null: false, default: 0
      t.integer :present_days, null: false, default: 0
      t.integer :half_days, null: false, default: 0
      t.integer :paid_leave_days, null: false, default: 0
      t.integer :unpaid_leave_days, null: false, default: 0
      t.integer :absent_days, null: false, default: 0
      t.decimal :payable_days, precision: 5, scale: 1, null: false, default: 0
      t.decimal :earned, precision: 10, scale: 2, null: false
      # what the admin added or took off
      t.decimal :bonus, precision: 10, scale: 2, null: false, default: 0
      t.string :bonus_note
      t.decimal :deduction, precision: 10, scale: 2, null: false, default: 0
      t.string :deduction_note
      t.decimal :net_amount, precision: 10, scale: 2, null: false
      # how it was paid
      t.string :mode, null: false, default: "cash"
      t.string :reference
      t.date :paid_on, null: false
      t.string :note
      t.string :paid_by
      t.timestamps
    end
    add_index :salary_payments, %i[team_member_id month], unique: true
    add_index :salary_payments, :month
  end

  def down
    drop_table :salary_payments if table_exists?(:salary_payments)
  end
end
