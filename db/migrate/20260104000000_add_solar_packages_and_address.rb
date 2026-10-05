class AddSolarPackagesAndAddress < ActiveRecord::Migration[7.1]
  def change
    create_table :solar_packages do |t|
      t.string :name, null: false
      t.decimal :capacity_kw, precision: 6, scale: 2, null: false
      t.integer :panel_count, null: false
      t.string :panel_brand, :inverter_model, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_reference :installations, :solar_package, foreign_key: true
    add_column :service_requests, :address, :text   # entered by the client on the contact form
  end
end
