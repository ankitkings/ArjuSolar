module Admin
  class QuotesController < BaseController
    def show
      @quote = Quote.includes(:service_request, :team_member).find(params[:id])
    end
  end
end
