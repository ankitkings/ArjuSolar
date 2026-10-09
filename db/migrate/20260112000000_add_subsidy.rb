class AddSubsidy < ActiveRecord::Migration[7.1]
  def change
    # The government subsidy rates, editable by the admin (the scheme can be revised)
    create_table :subsidy_schemes do |t|
      t.string  :name, null: false, default: "PM Surya Ghar: Muft Bijli Yojana"
      t.decimal :first_slab_kw, precision: 5,  scale: 2, null: false, default: 2        # first 2 kW ...
      t.decimal :first_rate,    precision: 10, scale: 2, null: false, default: 30000    # ... Rs 30,000 per kW
      t.decimal :cap_kw,        precision: 5,  scale: 2, null: false, default: 3        # subsidy stops growing at 3 kW
      t.decimal :second_rate,   precision: 10, scale: 2, null: false, default: 18000    # kW between 2 and 3: Rs 18,000
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_column :solar_packages, :subsidy_eligible, :boolean, null: false, default: true   # homes only
    add_column :quotes, :subsidy_applies, :boolean, null: false, default: false
    add_column :quotes, :subsidy_amount, :decimal, precision: 10, scale: 2, null: false, default: 0

    reversible do |dir|
      dir.up { execute "UPDATE solar_packages SET subsidy_eligible = FALSE WHERE name LIKE '%Commercial%'" }
    end
  end
end
