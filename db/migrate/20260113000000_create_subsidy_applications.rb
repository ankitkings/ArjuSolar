class CreateSubsidyApplications < ActiveRecord::Migration[7.1]
  def change
    # One PM Surya Ghar subsidy application per client request.
    # The client files it on the government portal; we record how it is going and what came of it.
    # (Aadhaar and bank account numbers are deliberately NOT stored here.)
    create_table :subsidy_applications do |t|
      t.references :service_request, null: false, foreign_key: true, index: { unique: true }
      t.string  :status, null: false, default: "preparing"
      t.string  :consumer_number, :discom, :portal_application_no
      t.decimal :system_capacity_kw, precision: 6, scale: 2
      t.decimal :expected_amount, precision: 10, scale: 2, null: false, default: 0
      t.decimal :received_amount, precision: 10, scale: 2
      t.date    :applied_on, :feasibility_on, :net_meter_on, :commissioned_on, :bank_submitted_on, :received_on
      t.text    :rejection_reason, :notes
      t.boolean :electricity_bill_received, :bank_account_confirmed, :cancelled_cheque_received,
                :roof_ownership_confirmed, null: false, default: false
      t.timestamps
    end
    add_index :subsidy_applications, :status
  end
end
