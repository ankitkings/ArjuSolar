# Cheques and bills. The Payment and Receipt models themselves stay as they are; this adds to them.
#  - a cheque counts as paid only after the bank confirms it ("received in bank")
#  - if the bank does not receive it, the payment is due again
#  - every payment gets a bill number the first time money is collected
Rails.application.config.to_prepare do
  Receipt.const_set(:CLEARING, { "pending" => "Waiting for the bank", "cleared" => "Received in the bank", "bounced" => "Not received in the bank" }.freeze) unless Receipt.const_defined?(:CLEARING, false)

  Receipt.class_eval do

    scope :waiting_for_bank, -> { where(mode: "cheque", clearing_status: "pending") }

    # every cheque starts as "waiting for the bank"
    before_validation(on: :create) { self.clearing_status = "pending" if mode == "cheque" && clearing_status.blank? }

    def counted? = clearing_status.nil? || clearing_status == "cleared"
    def waiting_for_bank? = clearing_status == "pending"
    def bounced? = clearing_status == "bounced"
    def clearing_label = Receipt::CLEARING[clearing_status]
    def cheque_no = (details || {})["cheque_no"]

    # only money that is really received counts
    def paid_to_date
      payment.receipts.where(clearing_status: [nil, "cleared"]).where("receipts.id <= ?", id).sum(:amount)
    end

    def balance_after
      payment.amount_due && payment.amount_due - paid_to_date
    end

    # The bank has received the cheque: it now counts. If that makes the payment complete, the request moves on to commissioning.
    def clear_in_bank!(by: nil, admin: nil)
      raise ArgumentError, "This cheque is not waiting for the bank." unless waiting_for_bank?
      request = payment.service_request
      transaction do
        update!(clearing_status: "cleared", cleared_on: Date.current)
        payment.reload.refresh_status!
        request.updates.create!(status: request.status, progress: request.progress, team_member: by, admin_user: admin,
                                note: "Cheque #{cheque_no}: received in the bank. #{Rupees.display(amount)} (#{number}) now counts as paid.")
        if payment.fully_paid? && request.status == "payment"
          request.advance!(to: "commissioning", by: by, admin: admin, note: "The cheque was received in the bank: payment received in full.")
        end
      end
    end

    # The bank did not receive the cheque: it does not count, and the payment process starts again.
    def bounce_in_bank!(reason: nil, by: nil, admin: nil)
      raise ArgumentError, "This cheque is not waiting for the bank." unless waiting_for_bank?
      request = payment.service_request
      transaction do
        update!(clearing_status: "bounced", bounced_on: Date.current, clearing_note: reason.to_s.strip.first(200).presence)
        payment.reload.refresh_status!
        request.updates.create!(status: request.status, progress: request.progress, team_member: by, admin_user: admin,
                                note: "Cheque #{cheque_no} was NOT received in the bank#{" (#{clearing_note})" if clearing_note}. Receipt #{number} does not count. " \
                                      "#{Rupees.display(payment.balance)} is due again: the cashier collects the payment once more.")
      end
    end
  end

  Payment.class_eval do
    # money received so far: a cheque waiting for the bank, or one the bank did not receive, is not counted
    def amount_paid
      if receipts.loaded?
        receipts.select(&:counted?).sum(&:amount)
      else
        receipts.where(clearing_status: [nil, "cleared"]).sum(:amount)
      end
    end

    def cheques_waiting = receipts.where(mode: "cheque", clearing_status: "pending")

    # the bill number is given once, when the first money is collected
    def issue_bill_number!
      return bill_number if bill_number.present?
      update_columns(bill_number: format("BILL-%d-%05d", Date.current.year, id), bill_issued_on: Date.current)
      bill_number
    end
  end
end
