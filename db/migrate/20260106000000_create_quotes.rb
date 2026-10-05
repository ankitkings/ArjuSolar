class CreateQuotes < ActiveRecord::Migration[7.1]
  def change
    create_table :quotes do |t|
      t.references :service_request, null: false, foreign_key: true
      t.references :solar_package, foreign_key: true
      t.references :team_member, foreign_key: true   # the site visitor who made it
      t.string :number
      t.string :status, null: false, default: "sent"   # sent / accepted / declined / superseded
      t.string :system_name, :panel_brand, :inverter_model
      t.decimal :capacity_kw, precision: 6, scale: 2
      t.integer :panel_count
      t.decimal :list_price, precision: 10, scale: 2, null: false
      t.decimal :discount, precision: 10, scale: 2, null: false, default: 0
      t.decimal :total, precision: 10, scale: 2, null: false
      t.date :valid_until, null: false
      t.text :notes
      t.timestamps
    end
    add_index :quotes, :number, unique: true
  end
end
