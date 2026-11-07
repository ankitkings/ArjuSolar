module Admin
  # Admin > Payment setup: our UPI id and bank account, shown to the client when the cashier collects money
  class PaymentSettingsController < BaseController
    def show
      @setting = PaymentSetting.current
      @qr_ready = UpiQr.available?
    end

    def update
      @setting = PaymentSetting.current
      if @setting.update(params.require(:payment_setting).permit(:upi_id, :upi_name, :bank_name, :branch, :account_name, :account_number, :ifsc))
        redirect_to admin_payment_settings_path, notice: "Payment details saved."
      else
        @qr_ready = UpiQr.available?
        render :show, status: :unprocessable_entity
      end
    end
  end
end
