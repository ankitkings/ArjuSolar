module Admin
  # The bill of a payment: the installed items, what was paid, what is due. Complete payment = the final bill.
  class BillsController < BaseController
    def show
      @payment = Payment.find(params[:payment_id])
      return redirect_to(admin_payment_path(@payment), alert: "Nothing was collected yet, so there is no bill.") if @payment.receipts.none?
      @payment.issue_bill_number!
      @bill = Bill.new(@payment)
    end
  end
end
