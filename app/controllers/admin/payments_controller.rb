module Admin
  # Admin: payments of every client, with their receipts
  class PaymentsController < BaseController
    def index
      @filter = params[:status].presence_in(Payment::STATUSES)
      scope = Payment.joins(:service_request)
                     .includes(:receipts, :team_member, service_request: { installation: :solar_package })
                     .order(created_at: :desc)
      scope = scope.where(status: @filter) if @filter
      if params[:q].present?
        q = "%#{Payment.sanitize_sql_like(params[:q])}%"
        scope = scope.where("service_requests.name LIKE :q OR service_requests.phone LIKE :q", q: q)
      end
      @payments = scope.to_a
      @total_due   = @payments.sum { |p| p.amount_due || 0 }
      @collected   = @payments.sum(&:amount_paid)
      @outstanding = @payments.sum { |p| p.balance || 0 }
    end

    def show
      @payment = Payment.includes(:receipts, service_request: { installation: :solar_package }).find(params[:id])
    end

    # Admin can correct the total amount due (e.g. discount / subsidy adjustment)
    def update
      @payment = Payment.find(params[:id])
      due = parse_amount(params[:amount_due])
      if due.nil? || due <= 0
        redirect_to admin_payment_path(@payment), alert: "Enter a valid amount."
      elsif due < @payment.amount_paid
        redirect_to admin_payment_path(@payment), alert: "Already collected more than that (#{Rupees.display(@payment.amount_paid)})."
      else
        old = @payment.amount_due
        Payment.transaction do
          @payment.update!(amount_due: due)
          @payment.refresh_status!
          req = @payment.service_request
          reason = params[:reason].to_s.strip.presence
          req.updates.create!(status: req.status, progress: req.progress, admin_user: current_admin,
                              note: "Amount due changed from #{Rupees.display(old)} to #{Rupees.display(due)} by admin#{": #{reason}" if reason}")
        end
        redirect_to admin_payment_path(@payment), notice: "Amount due updated"
      end
    end

    private

    def parse_amount(value)
      BigDecimal(value.to_s.strip)
    rescue ArgumentError
      nil
    end
  end
end
