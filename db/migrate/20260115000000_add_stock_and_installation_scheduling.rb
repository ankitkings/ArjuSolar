# frozen_string_literal: true

class AddStockAndInstallationScheduling < ActiveRecord::Migration[7.1]
  def change
    # stock of every physical part (labour / services are not stocked)
    add_column :catalog_items, :stock_quantity, :decimal, precision: 10, scale: 2, null: false, default: 0
    add_column :catalog_items, :min_stock, :decimal, precision: 10, scale: 2, null: false, default: 0 # order again below this

    # when the installation of an accepted quote is planned
    add_column :service_requests, :installation_scheduled_on, :date
    add_column :service_requests, :installation_status, :string # "scheduled" or "waiting_for_stock"

    # every change of the stock: received, used on a job, or corrected after a count
    create_table :stock_movements do |t|
      t.references :catalog_item, null: false, foreign_key: true
      t.references :service_request, foreign_key: true
      t.decimal :quantity, precision: 10, scale: 2, null: false   # + in, - out
      t.string :kind, null: false                                 # received / used / adjustment
      t.string :note
      t.timestamps
    end

    # parts set aside for a scheduled installation
    create_table :stock_reservations do |t|
      t.references :service_request, null: false, foreign_key: true
      t.references :catalog_item, null: false, foreign_key: true
      t.decimal :quantity, precision: 10, scale: 2, null: false
      t.timestamps
    end
    add_index :stock_reservations, %i[service_request_id catalog_item_id], unique: true,
                                                                           name: 'index_stock_reservations_uniqueness'

    # the rules for planning installations (one row)
    create_table :installation_settings do |t|
      t.integer :cutoff_hour, null: false, default: 15            # accepted before 3 PM -> can start today
      t.integer :work_end_hour, null: false, default: 19          # working day ends at 7 PM
      t.integer :jobs_per_installer_per_day, null: false, default: 1
      t.boolean :sunday_off, null: false, default: true
      t.timestamps
    end
  end
end
