module Admin
  class ChequeClearancesController < BaseController
    include ChequeClearanceActions

    private

    def cheque_receipt = Receipt.find(params[:receipt_id])
    def actor = { admin: current_admin }
    def payment_page(receipt) = admin_payment_path(receipt.payment)
  end
end
