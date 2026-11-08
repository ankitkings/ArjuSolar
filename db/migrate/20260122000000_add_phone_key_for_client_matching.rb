# Safe to run again: every step first checks what already exists in the database.
class AddPhoneKeyForClientMatching < ActiveRecord::Migration[7.1]
  def up
    # the last 10 digits of a phone number, so "+91 98765-43210" and "9876543210" count as the same number
    add_column :customers, :phone_key, :string unless column_exists?(:customers, :phone_key)
    add_column :service_requests, :phone_key, :string unless column_exists?(:service_requests, :phone_key)
    add_index :customers, :phone_key unless index_exists?(:customers, :phone_key)
    add_index :service_requests, :phone_key unless index_exists?(:service_requests, :phone_key)

    %w[customers service_requests].each do |table|
      select_rows("SELECT id, phone FROM #{table}").each do |id, phone|
        key = phone.to_s.gsub(/\D/, "").last(10)
        execute("UPDATE #{table} SET phone_key = #{quote(key)} WHERE id = #{id.to_i}")
      end
    end

    # requests that already carry the e-mail of a client profile join that client
    execute <<~SQL
      UPDATE service_requests
      SET customer_id = (SELECT customers.id FROM customers WHERE customers.email = LOWER(service_requests.email))
      WHERE customer_id IS NULL AND email IS NOT NULL
        AND LOWER(email) IN (SELECT email FROM customers)
    SQL
  end

  def down
    remove_index :service_requests, :phone_key if index_exists?(:service_requests, :phone_key)
    remove_index :customers, :phone_key if index_exists?(:customers, :phone_key)
    remove_column :service_requests, :phone_key if column_exists?(:service_requests, :phone_key)
    remove_column :customers, :phone_key if column_exists?(:customers, :phone_key)
  end
end
