module Staff
  # The cashier's view of the bill of one of his payments
  class BillsController < BaseController
    def show
      @payment = current_staff.payments.find(params[:payment_id])
      return redirect_to(staff_payment_path(@payment), alert: "Nothing was collected yet, so there is no bill.") if @payment.receipts.none?
      @payment.issue_bill_number!
      @bill = Bill.new(@payment)
    end
  end
end
