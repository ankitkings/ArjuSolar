class AddPricingAndReceipts < ActiveRecord::Migration[7.1]
  def change
    add_column :solar_packages, :price, :decimal, precision: 10, scale: 2   # package amount
    add_column :installations, :package_price, :decimal, precision: 10, scale: 2   # copied when installed
    add_column :payments, :amount_due, :decimal, precision: 10, scale: 2

    create_table :receipts do |t|
      t.references :payment, null: false, foreign_key: true
      t.references :team_member, foreign_key: true   # cashier who collected it
      t.string :number
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :mode, null: false, default: "cash"
      t.string :reference
      t.date :received_on, null: false
      t.text :note
      t.timestamps
    end
    add_index :receipts, :number, unique: true

    # Keep payments recorded with the earlier version: they become one receipt each
    reversible do |dir|
      dir.up do
        execute "UPDATE payments SET amount_due = amount WHERE amount IS NOT NULL"
        execute <<~SQL
          INSERT INTO receipts (payment_id, team_member_id, number, amount, mode, received_on, created_at, updated_at)
          SELECT id, team_member_id, 'RCT-OLD-' || id, amount, 'cash', COALESCE(received_on, CURRENT_DATE), created_at, updated_at
          FROM payments WHERE status = 'received' AND amount IS NOT NULL
        SQL
      end
    end
  end
end
