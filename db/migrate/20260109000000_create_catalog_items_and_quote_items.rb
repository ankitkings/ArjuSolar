class CreateCatalogItemsAndQuoteItems < ActiveRecord::Migration[7.1]
  def change
    # Every part we sell, each with its own price (panels by model, inverters by model / kW, structure, cables, labour ...)
    create_table :catalog_items do |t|
      t.string :category, null: false
      t.string :name, null: false
      t.string :unit, null: false, default: "piece"
      t.decimal :unit_price, precision: 10, scale: 2, null: false
      t.decimal :capacity_kw, precision: 6, scale: 3   # per unit: a panel's kW, an inverter's rating
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :catalog_items, %i[category name]

    # One line of a custom quote (name and price are copied, so later price changes never alter a sent quote)
    create_table :quote_items do |t|
      t.references :quote, null: false, foreign_key: true
      t.references :catalog_item, foreign_key: true
      t.string :category
      t.string :description, null: false
      t.string :unit
      t.decimal :quantity, precision: 8, scale: 2, null: false, default: 1
      t.decimal :unit_price, precision: 10, scale: 2, null: false
      t.decimal :capacity_kw, precision: 6, scale: 3
      t.decimal :line_total, precision: 12, scale: 2, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    # an installation can be made from an accepted custom quote instead of a catalog package
    add_reference :installations, :quote, foreign_key: { on_delete: :nullify }
  end
end
