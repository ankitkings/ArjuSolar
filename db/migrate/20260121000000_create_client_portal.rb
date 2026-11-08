# Safe to run again: every step first checks what already exists in the database.
class CreateClientPortal < ActiveRecord::Migration[7.1]
  def up
    # clients who have a profile (made by the admin)
    unless table_exists?(:customers)
      create_table :customers do |t|
        t.string :name, null: false
        t.string :email, null: false
        t.string :phone, null: false
        t.string :password_digest                      # empty until the client sets a password from the e-mail link
        t.datetime :password_set_at
        t.integer :failed_attempts, null: false, default: 0
        t.datetime :locked_until
        t.datetime :last_login_at
        t.datetime :setup_sent_at                      # last time a set-password / reset link was e-mailed
        t.timestamps
      end
    end
    # columns an earlier, interrupted run may have missed
    ensure_column :customers, :name, :string, null: false, default: ""
    ensure_column :customers, :email, :string, null: false, default: ""
    ensure_column :customers, :phone, :string, null: false, default: ""
    ensure_column :customers, :password_digest, :string
    ensure_column :customers, :password_set_at, :datetime
    ensure_column :customers, :failed_attempts, :integer, null: false, default: 0
    ensure_column :customers, :locked_until, :datetime
    ensure_column :customers, :last_login_at, :datetime
    ensure_column :customers, :setup_sent_at, :datetime
    add_index :customers, :email, unique: true unless index_exists?(:customers, :email)

    # a request can belong to a client
    add_reference :service_requests, :customer, foreign_key: true unless column_exists?(:service_requests, :customer_id)

    # visits asked for by the client because of an issue (inside the warranty)
    ensure_column :maintenance_visits, :kind, :string, null: false, default: "check"   # check / client_issue
    ensure_column :maintenance_visits, :issue_details, :text

    unless table_exists?(:portal_settings)
      create_table :portal_settings do |t|
        t.integer :warranty_months, null: false, default: 60
        t.timestamps
      end
    end
  end

  def down
    drop_table :portal_settings if table_exists?(:portal_settings)
    remove_column :maintenance_visits, :issue_details if column_exists?(:maintenance_visits, :issue_details)
    remove_column :maintenance_visits, :kind if column_exists?(:maintenance_visits, :kind)
    remove_reference :service_requests, :customer, foreign_key: true if column_exists?(:service_requests, :customer_id)
    drop_table :customers if table_exists?(:customers)
  end

  private

  def ensure_column(table, name, type, **options)
    add_column(table, name, type, **options) unless column_exists?(table, name)
  end
end
