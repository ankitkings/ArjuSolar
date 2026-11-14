# Safe to run again. Remembers, for every admin and every menu module, when the module was last opened,
# so the menu can show how many new things came in since then.
class CreateModuleSeens < ActiveRecord::Migration[7.1]
  def up
    return if table_exists?(:module_seens)
    create_table :module_seens do |t|
      t.references :admin_user, null: false, foreign_key: { on_delete: :cascade }
      t.string :module_key, null: false
      t.datetime :seen_at, null: false
      t.timestamps
    end
    add_index :module_seens, %i[admin_user_id module_key], unique: true
  end

  def down
    drop_table :module_seens if table_exists?(:module_seens)
  end
end
