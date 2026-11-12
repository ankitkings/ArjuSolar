# "Received in the bank" / "Not received" for a cheque (used by the admin and by the cashier)
module ChequeClearanceActions
  extend ActiveSupport::Concern

  def clear
    receipt = cheque_receipt
    receipt.clear_in_bank!(**actor)
    message = "Cheque #{receipt.cheque_no}: received in the bank."
    message += " The payment is complete and the request moved to commissioning." if receipt.payment.reload.fully_paid?
    redirect_to payment_page(receipt), notice: message
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    redirect_to payment_page(receipt), alert: e.message
  end

  def bounce
    receipt = cheque_receipt
    receipt.bounce_in_bank!(reason: params[:reason], **actor)
    redirect_to payment_page(receipt), notice: "Cheque #{receipt.cheque_no}: not received in the bank. The payment of #{Rupees.display(receipt.payment.reload.balance)} is due again."
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    redirect_to payment_page(receipt), alert: e.message
  end
end
