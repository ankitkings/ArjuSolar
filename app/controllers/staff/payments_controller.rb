module Staff
  class PaymentsController < BaseController
    before_action :set_payment

    def show; end

    def update
      if @payment.status == "received"
        return redirect_to(staff_root_path, alert: "This payment is already marked as received.")
      end
      @payment.receive!(amount: params[:amount], note: params[:note])
      redirect_to staff_root_path, notice: "Payment recorded"
    rescue ActiveRecord::RecordInvalid
      render :show, status: :unprocessable_entity
    end

    private

    def set_payment
      @payment = current_staff.payments.find(params[:id])
    end
  end
end
