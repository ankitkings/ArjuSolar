module Admin
  class QuotesController < BaseController
    def show
      @quote = Quote.includes(:service_request, :team_member).find(params[:id])
    end

    def pdf
      quote = Quote.find(params[:id])
      send_data QuotePdf.render(quote), filename: "Quotation-#{quote.number}.pdf", type: "application/pdf", disposition: "attachment"
    end
  end
end
