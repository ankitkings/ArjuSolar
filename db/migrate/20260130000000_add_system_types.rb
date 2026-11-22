# Safe to run again. Every solar system and every quotation is on-grid, off-grid or hybrid.
class AddSystemTypes < ActiveRecord::Migration[7.1]
  def up
    add_column :solar_packages, :system_type, :string, null: false, default: "on_grid" unless column_exists?(:solar_packages, :system_type)
    add_column :quotes, :system_type, :string, null: false, default: "on_grid" unless column_exists?(:quotes, :system_type)

    # what already exists keeps working: anything with a battery is hybrid (or off-grid when its quotation had no subsidy)
    execute <<~SQL
      UPDATE solar_packages SET system_type = 'hybrid'
      WHERE id IN (SELECT pi.solar_package_id FROM package_items pi JOIN catalog_items ci ON ci.id = pi.catalog_item_id WHERE ci.category = 'battery')
    SQL
    execute <<~SQL
      UPDATE quotes SET system_type = CASE WHEN subsidy_applies THEN 'hybrid' ELSE 'off_grid' END
      WHERE id IN (SELECT DISTINCT quote_id FROM quote_items WHERE category = 'battery')
    SQL
  end

  def down
    remove_column :quotes, :system_type if column_exists?(:quotes, :system_type)
    remove_column :solar_packages, :system_type if column_exists?(:solar_packages, :system_type)
  end
end
