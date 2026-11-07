class AddPaymentMethods < ActiveRecord::Migration[7.1]
  def change
    # what the cashier entered for the way the client paid: notes counted, cheque, UPI, bank transfer or card details
    add_column :receipts, :details, :json

    # our own UPI id and bank account: shown as a QR code / on screen to the client
    create_table :payment_settings do |t|
      t.string :upi_id
      t.string :upi_name
      t.string :bank_name
      t.string :branch
      t.string :account_name
      t.string :account_number
      t.string :ifsc
      t.timestamps
    end
  end
end
