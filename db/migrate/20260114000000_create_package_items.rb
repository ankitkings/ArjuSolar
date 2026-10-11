class CreatePackageItems < ActiveRecord::Migration[7.1]
  def change
    # The parts a ready-made system is made of (with quantities). The system's price is the sum of these parts.
    create_table :package_items do |t|
      t.references :solar_package, null: false, foreign_key: true
      t.references :catalog_item, null: false, foreign_key: true
      t.decimal :quantity, precision: 8, scale: 2, null: false, default: 1
      t.integer :position, null: false, default: 0
      t.timestamps
    end
  end
end
