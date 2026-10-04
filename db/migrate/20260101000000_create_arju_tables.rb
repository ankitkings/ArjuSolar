class CreateArjuTables < ActiveRecord::Migration[7.1]
  def change
    create_table :admin_users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.timestamps
    end
    add_index :admin_users, :email, unique: true

    create_table :visits do |t|
      t.string :ip_address, :user_agent, :browser, :os, :device, :path, :referrer
      t.datetime :visited_at, null: false
    end
    add_index :visits, :visited_at
    add_index :visits, :ip_address

    create_table :team_members do |t|
      t.string :name, null: false
      t.string :department, null: false
      t.string :phone
      t.text :bio
      t.boolean :show_on_website, default: true, null: false
      t.boolean :active, default: true, null: false
      t.timestamps
    end

    create_table :service_requests do |t|
      t.string :name, :phone, null: false
      t.string :email, :ip_address
      t.text :message
      t.string :status, null: false, default: "pending"
      t.integer :progress, null: false, default: 0
      t.references :team_member, foreign_key: true
      t.timestamps
    end
    add_index :service_requests, :status

    create_table :request_updates do |t|
      t.references :service_request, null: false, foreign_key: true
      t.references :admin_user, foreign_key: true
      t.string :status
      t.integer :progress
      t.text :note
      t.timestamps
    end
  end
end
