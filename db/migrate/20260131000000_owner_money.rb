# Safe to run again. The owner's password, the cost of the parts of each quotation, the wallet and the other expenses.
class OwnerMoney < ActiveRecord::Migration[7.1]
  def up
    unless table_exists?(:owner_locks)
      create_table :owner_locks do |t|
        t.string :password_digest, null: false
        t.integer :failed_attempts, null: false, default: 0
        t.datetime :locked_until
        t.timestamps
      end
    end

    # what the parts cost us when the quotation was made (so later price changes do not change old profits)
    add_column :quote_items, :cost_price, :decimal, precision: 10, scale: 2 unless column_exists?(:quote_items, :cost_price)

    unless table_exists?(:wallets)
      create_table :wallets do |t|
        t.decimal :opening_balance, precision: 14, scale: 2, null: false, default: 0
        t.date :opened_on
        t.boolean :enabled, null: false, default: false
        t.boolean :deduct_salaries, null: false, default: false      # salaries paid also leave the wallet
        t.boolean :add_client_payments, null: false, default: false  # money received from clients also enters the wallet
        t.timestamps
      end
    end

    unless table_exists?(:wallet_entries)
      create_table :wallet_entries do |t|
        t.string :kind, null: false                                   # deposit / withdrawal / order / order_refund / salary / salary_refund / client_payment
        t.decimal :amount, precision: 14, scale: 2, null: false       # + money in, - money out
        t.date :happened_on, null: false
        t.string :label
        t.string :source_type
        t.bigint :source_id
        t.timestamps
      end
      add_index :wallet_entries, %i[source_type source_id kind], unique: true
      add_index :wallet_entries, :happened_on
    end

    unless table_exists?(:expenses)
      create_table :expenses do |t|
        t.date :spent_on, null: false
        t.string :label, null: false
        t.decimal :amount, precision: 12, scale: 2, null: false
        t.string :note
        t.timestamps
      end
      add_index :expenses, :spent_on
    end
  end

  def down
    drop_table :expenses if table_exists?(:expenses)
    drop_table :wallet_entries if table_exists?(:wallet_entries)
    drop_table :wallets if table_exists?(:wallets)
    remove_column :quote_items, :cost_price if column_exists?(:quote_items, :cost_price)
    drop_table :owner_locks if table_exists?(:owner_locks)
  end
end
