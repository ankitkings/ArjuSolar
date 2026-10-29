module Staff
  # Cashier: collect an amount against a payment (cash, UPI, bank transfer, cheque or card) and get a numbered receipt
  class PaymentsController < BaseController
    before_action :set_payment

    def show; end

    def update
      if @payment.fully_paid?
        return redirect_to(staff_payment_path(@payment), alert: "This payment is already fully received.")
      end

      mode = params[:mode].to_s
      amount = parse_amount(params[:amount])
      return fail_with("Choose how the client is paying.") unless Receipt::MODES.key?(mode)
      return fail_with("Enter a valid amount.") if amount.nil? || amount <= 0

      built = PaymentMethods.build(mode, params[:details], amount: amount)
      return fail_with(built.errors.to_sentence) if built.errors.any?

      receipt = nil
      Payment.transaction do
        if @payment.amount_due.nil?   # older payments without a price: the cashier enters the total once
          @payment.update!(amount_due: params[:amount_due].presence)
          raise ActiveRecord::RecordInvalid, @payment if @payment.amount_due.nil?
        end
        receipt = @payment.collect!(amount: amount, mode: mode, reference: built.reference, note: params[:note], by: current_staff)
        receipt.update!(details: built.details)   # notes counted, cheque / UPI / transfer / card details
      end

      msg = "Payment recorded. Receipt #{receipt.number} created."
      req = @payment.service_request
      if req.status == "commissioning"
        msg += " Paid in full – the request moved to 95% and was assigned to #{req.team_member&.name || 'Daily Servicing (nobody available – admin must assign)'}."
      end
      redirect_to staff_receipt_path(receipt), notice: msg
    rescue ActiveRecord::RecordInvalid => e
      fail_with(e.record.errors.full_messages.to_sentence.presence || "Enter the total amount due.")
    end

    # The UPI QR code for the amount the client is going to pay now
    def upi_qr
      setting = PaymentSetting.current
      amount = parse_amount(params[:amount])
      if !setting.upi_ready?
        render json: { error: "Our UPI id is not set. Ask the admin to add it under Payment setup." }, status: :unprocessable_entity
      elsif amount.nil? || amount <= 0 || (@payment.balance && amount > @payment.balance)
        render json: { error: "Enter an amount that is not more than the balance (#{Rupees.display(@payment.balance)})." }, status: :unprocessable_entity
      else
        link = setting.upi_link(amount: amount, note: "Arju Solars request #{@payment.service_request_id}")
        render json: { link: link, svg: UpiQr.svg(link), upi_id: setting.upi_id }
      end
    end

    private

    def fail_with(message)
      @error = message
      @payment.reload
      render :show, status: :unprocessable_entity
    end

    def parse_amount(value)
      BigDecimal(value.to_s.strip)
    rescue ArgumentError
      nil
    end

    def set_payment
      @payment = current_staff.payments.includes(:receipts).find(params[:id])
    end
  end
end
