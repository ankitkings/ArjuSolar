module Staff
  # Site visitor: create a quote - from a ready-made system, or by arranging individual parts.
  # Everyone involved can view / print it.
  class QuotesController < BaseController
    before_action :set_task, only: %i[new create]

    # The "arrange the parts" builder
    def new
      return redirect_to(staff_task_path(@task), alert: "A quote can only be made after the site visit.") unless quoting_allowed?
      @quote = Quote.new
      @initial = []
    end

    def create
      return redirect_to(staff_task_path(@task), alert: "A quote can only be made after the site visit.") unless quoting_allowed?

      first_quote = @task.status == "site_visit"
      if params.key?(:items)
        items = custom_items
        if items.empty?
          @quote, @initial, @error = Quote.new, [], "Choose at least one part."
          return render(:new, status: :unprocessable_entity)
        end
        quote = @task.create_quote!(items: items, system_name: params[:system_name], discount: params[:discount],
                                    valid_until: params[:valid_until], notes: params[:notes],
                                    subsidy_applies: params[:subsidy_applies] == "1", by: current_staff)
      else
        attrs = quote_params
        quote = @task.create_quote!(package: SolarPackage.find_by(id: attrs[:solar_package_id]), discount: attrs[:discount],
                                    valid_until: attrs[:valid_until], notes: attrs[:notes],
                                    subsidy_applies: attrs[:subsidy_applies], by: current_staff)
      end
      msg = "Quote #{quote.number} created."
      msg += " The request moved to Quote sent." if first_quote
      redirect_to staff_quote_path(quote), notice: msg
    rescue ActiveRecord::RecordInvalid => e
      @quote = e.record.is_a?(Quote) ? e.record : Quote.new
      @error = e.record.errors.full_messages.to_sentence unless e.record.is_a?(Quote)
      if params.key?(:items)
        @initial = initial_rows
        render :new, status: :unprocessable_entity
      else
        @installation = @task.new_installation
        render "staff/tasks/show", status: :unprocessable_entity
      end
    end

    def show
      @quote = visible_quotes.find(params[:id])
    end

    # Records that the quote was sent, then opens WhatsApp (in the new tab the button opens) with the message ready
    def whatsapp
      quote = visible_quotes.find(params[:id])
      back = staff_quote_path(quote)
      return redirect_to(back, alert: "Only a current quote can be sent. Create a new quote first.") unless %w[sent accepted].include?(quote.status)
      return redirect_to(back, alert: "This quote has expired. Revise it before sending.") if quote.expired?
      if Quote.whatsapp_number(quote.service_request.phone).length < 11
        return redirect_to(back, alert: "The client's phone number does not look like a WhatsApp number. Check it with the contact person.")
      end

      log_whatsapp_send(quote, "sent to the client on WhatsApp (#{quote.service_request.phone})")
      redirect_to quote.whatsapp_url(helpers.public_quote_link(quote), current_staff.name, pdf_link: helpers.public_quote_pdf_link(quote)), allow_other_host: true
    end

    # The quotation as a PDF file
    def pdf
      quote = visible_quotes.find(params[:id])
      send_data QuotePdf.render(quote), filename: "Quotation-#{quote.number}.pdf", type: "application/pdf", disposition: "attachment"
    end

    # Called by the "Share PDF on WhatsApp" button after the phone's share sheet was used
    def shared
      quote = visible_quotes.find(params[:id])
      log_whatsapp_send(quote, "PDF shared on WhatsApp")
      head :ok
    end

    private

    def log_whatsapp_send(quote, what)
      req = quote.service_request
      Quote.transaction do
        quote.update_columns(whatsapp_sent_at: Time.current)
        req.updates.create!(status: req.status, progress: req.progress, team_member: current_staff,
                            note: "Quote #{quote.number} (#{Rupees.display(quote.total)}) #{what}")
      end
    end

    # quotes this person may open: of requests assigned to them, or made by them
    def visible_quotes
      Quote.joins(:service_request)
           .where("service_requests.team_member_id = :id OR quotes.team_member_id = :id", id: current_staff.id)
    end

    def set_task
      @task = current_staff.service_requests.find(params[:task_id])
    end

    def quoting_allowed?
      %w[site_visit quote_sent].include?(@task.status)
    end

    def quote_params
      params.require(:quote).permit(:solar_package_id, :discount, :valid_until, :notes, :subsidy_applies)
    end

    # [[catalog_item, quantity], ...] - prices are always taken from the price list, never from the browser
    def custom_items
      Array(params[:items]).filter_map do |row|
        item = CatalogItem.find_by(id: row[:catalog_item_id])
        [item, row[:quantity]] if item
      end
    end

    # rows to show again when the form had a mistake
    def initial_rows
      Array(params[:items]).filter_map do |row|
        { id: row[:catalog_item_id].to_i, qty: row[:quantity] } if row[:catalog_item_id].present?
      end
    end
  end
end
