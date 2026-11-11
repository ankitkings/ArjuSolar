# Safe to run again: it only creates what is missing.
class CreateHolidays < ActiveRecord::Migration[7.1]
  def up
    return if table_exists?(:holidays)
    create_table :holidays do |t|
      t.date :date, null: false
      t.string :name, null: false
      t.string :kind, null: false, default: "festival"   # national / festival / company / other
      t.string :note
      t.timestamps
    end
    add_index :holidays, :date, unique: true
  end

  def down
    drop_table :holidays if table_exists?(:holidays)
  end
end
