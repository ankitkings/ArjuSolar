module Admin
  class ReceiptsController < BaseController
    def show
      @receipt = Receipt.includes(payment: :service_request).find(params[:id])
    end
  end
end
