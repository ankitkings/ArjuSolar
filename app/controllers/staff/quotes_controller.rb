module Staff
  # Site visitor: create a quote from the price list. Everyone involved can view / print it.
  class QuotesController < BaseController
    def create
      @task = current_staff.service_requests.find(params[:task_id])
      unless %w[site_visit quote_sent].include?(@task.status)
        return redirect_to(staff_task_path(@task), alert: "A quote can only be created after the site visit.")
      end

      first_quote = @task.status == "site_visit"
      attrs = quote_params
      quote = @task.create_quote!(package: SolarPackage.find_by(id: attrs[:solar_package_id]), discount: attrs[:discount],
                                  valid_until: attrs[:valid_until], notes: attrs[:notes], by: current_staff)
      msg = "Quote #{quote.number} created."
      msg += " The request moved to Quote sent." if first_quote
      redirect_to staff_quote_path(quote), notice: msg
    rescue ActiveRecord::RecordInvalid => e
      @quote = e.record.is_a?(Quote) ? e.record : Quote.new
      @installation = Installation.new(installed_on: Date.current, site_address: @task.address)
      render "staff/tasks/show", status: :unprocessable_entity
    end

    def show
      @quote = Quote.joins(:service_request)
                    .where("service_requests.team_member_id = :id OR quotes.team_member_id = :id", id: current_staff.id)
                    .find(params[:id])
    end

    private

    def quote_params
      params.require(:quote).permit(:solar_package_id, :discount, :valid_until, :notes)
    end
  end
end
