module Staff
  class ChequeClearancesController < BaseController
    include ChequeClearanceActions

    private

    # a cashier handles the cheques of his own payments
    def cheque_receipt = Receipt.where(payment_id: current_staff.payments.select(:id)).find(params[:receipt_id])
    def actor = { by: current_staff }
    def payment_page(receipt) = staff_payment_path(receipt.payment)
  end
end
