module Staff
  class ReceiptsController < BaseController
    def show
      @receipt = Receipt.joins(:payment)
                        .where("payments.team_member_id = :id OR receipts.team_member_id = :id", id: current_staff.id)
                        .find(params[:id])
    end
  end
end
