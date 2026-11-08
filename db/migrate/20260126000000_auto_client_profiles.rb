# Safe to run again. Makes a client profile for every person who already sent a request (once, now).
class AutoClientProfiles < ActiveRecord::Migration[7.1]
  def up
    add_column :customers, :auto_created, :boolean, null: false, default: false unless column_exists?(:customers, :auto_created)
    Customer.reset_column_information
    ServiceRequest.reset_column_information
    made, linked, left = Customer.backfill_from_requests!
    say "#{made} client profiles made, #{linked} requests linked, #{left} requests left without a profile (no e-mail address)"
  end

  def down
    remove_column :customers, :auto_created if column_exists?(:customers, :auto_created)
  end
end
