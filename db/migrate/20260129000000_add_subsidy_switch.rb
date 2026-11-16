# Safe to run again. The master switch of the subsidy (PM Surya Ghar): on = the subsidy works everywhere, off = it is left out.
class AddSubsidySwitch < ActiveRecord::Migration[7.1]
  def up
    add_column :site_settings, :subsidy_enabled, :boolean, null: false, default: true unless column_exists?(:site_settings, :subsidy_enabled)
  end

  def down
    remove_column :site_settings, :subsidy_enabled if column_exists?(:site_settings, :subsidy_enabled)
  end
end
