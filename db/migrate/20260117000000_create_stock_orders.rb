class CreateStockOrders < ActiveRecord::Migration[7.1]
  def change
    # parts ordered from a supplier and not arrived yet
    create_table :stock_orders do |t|
      t.references :catalog_item, null: false, foreign_key: true
      t.decimal :quantity, precision: 10, scale: 2, null: false
      t.decimal :quantity_received, precision: 10, scale: 2
      t.string :status, null: false, default: "ordered"   # ordered / received / cancelled
      t.string :supplier
      t.string :note
      t.date :ordered_on, null: false
      t.date :received_on
      t.timestamps
    end
    add_index :stock_orders, :status
  end
end
