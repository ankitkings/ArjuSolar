module Staff
  # Cashier: collect an amount against a payment and get a numbered receipt
  class PaymentsController < BaseController
    before_action :set_payment

    def show; end

    def update
      if @payment.fully_paid?
        return redirect_to(staff_payment_path(@payment), alert: "This payment is already fully received.")
      end

      receipt = nil
      Payment.transaction do
        if @payment.amount_due.nil?   # older payments without a price: the cashier enters the total once
          @payment.update!(amount_due: params[:amount_due].presence)
          raise ActiveRecord::RecordInvalid, @payment if @payment.amount_due.nil?
        end
        receipt = @payment.collect!(amount: params[:amount], mode: params[:mode], reference: params[:reference],
                                    note: params[:note], by: current_staff)
      end
      msg = "Payment recorded. Receipt #{receipt.number} created."
      req = @payment.service_request
      if req.status == "commissioning"
        msg += " Paid in full – the request moved to 95% and was assigned to #{req.team_member&.name || 'Daily Servicing (nobody available – admin must assign)'}."
      end
      redirect_to staff_receipt_path(receipt), notice: msg
    rescue ActiveRecord::RecordInvalid => e
      @error = e.record.errors.full_messages.to_sentence.presence || "Enter the total amount due."
      @payment.reload
      render :show, status: :unprocessable_entity
    end

    private

    def set_payment
      @payment = current_staff.payments.includes(:receipts).find(params[:id])
    end
  end
end
