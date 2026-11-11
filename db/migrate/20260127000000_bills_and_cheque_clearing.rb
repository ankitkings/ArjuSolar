# Safe to run again: every step first checks what already exists.
class BillsAndChequeClearing < ActiveRecord::Migration[7.1]
  def up
    # GST details printed at the top of every bill
    add_column :site_settings, :legal_name, :string unless column_exists?(:site_settings, :legal_name)
    add_column :site_settings, :gstin, :string unless column_exists?(:site_settings, :gstin)
    add_column :site_settings, :gst_rate, :decimal, precision: 5, scale: 2, null: false, default: 0 unless column_exists?(:site_settings, :gst_rate)

    # the bill of a payment
    add_column :payments, :bill_number, :string unless column_exists?(:payments, :bill_number)
    add_column :payments, :bill_issued_on, :date unless column_exists?(:payments, :bill_issued_on)

    # a cheque is paid only when the bank has received it: pending / cleared / bounced (empty for every other way of paying)
    add_column :receipts, :clearing_status, :string unless column_exists?(:receipts, :clearing_status)
    add_column :receipts, :cleared_on, :date unless column_exists?(:receipts, :cleared_on)
    add_column :receipts, :bounced_on, :date unless column_exists?(:receipts, :bounced_on)
    add_column :receipts, :clearing_note, :string unless column_exists?(:receipts, :clearing_note)
    add_index :receipts, :clearing_status unless index_exists?(:receipts, :clearing_status)
  end

  def down
    remove_index :receipts, :clearing_status if index_exists?(:receipts, :clearing_status)
    %i[clearing_note bounced_on cleared_on clearing_status].each { |c| remove_column :receipts, c if column_exists?(:receipts, c) }
    %i[bill_issued_on bill_number].each { |c| remove_column :payments, c if column_exists?(:payments, c) }
    %i[gst_rate gstin legal_name].each { |c| remove_column :site_settings, c if column_exists?(:site_settings, c) }
  end
end
