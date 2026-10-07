# The page a client opens from the WhatsApp message. No login: the long secret token in the link is the key.
class PublicQuotesController < ApplicationController
  def show
    @quote = find_quote
    response.set_header("X-Robots-Tag", "noindex, nofollow")
  end

  def pdf
    quote = find_quote
    response.set_header("X-Robots-Tag", "noindex, nofollow")
    send_data QuotePdf.render(quote), filename: "Quotation-#{quote.number}.pdf", type: "application/pdf", disposition: "inline"
  end

  private

  def find_quote
    Quote.includes(:quote_items, :team_member, :service_request).find_by!(public_token: params[:token])
  end
end
