class AddWorkflowTables < ActiveRecord::Migration[7.1]
  def change
    create_table :installations do |t|
      t.references :service_request, null: false, foreign_key: true, index: { unique: true }
      t.date :installed_on, null: false
      t.decimal :capacity_kw, precision: 6, scale: 2, null: false
      t.integer :panel_count
      t.string :panel_brand, :inverter_model
      t.text :site_address, :notes
      t.timestamps
    end

    create_table :maintenance_visits do |t|
      t.references :service_request, null: false, foreign_key: true
      t.references :installation, null: false, foreign_key: true
      t.references :team_member, foreign_key: true
      t.string :title, null: false
      t.date :due_on, null: false
      t.string :status, null: false, default: "scheduled"
      t.datetime :assigned_at, :completed_at
      t.text :report
      t.timestamps
    end
    add_index :maintenance_visits, %i[status due_on]

    create_table :payments do |t|
      t.references :service_request, null: false, foreign_key: true, index: { unique: true }
      t.references :team_member, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.decimal :amount, precision: 10, scale: 2
      t.date :received_on
      t.text :note
      t.timestamps
    end
  end
end
