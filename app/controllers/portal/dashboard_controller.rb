module Portal
  # The client's home: all requests with their progress, warranty and reported issues
  class DashboardController < BaseController
    def show
      @requests = current_customer.service_requests.includes(:installation, :payment).order(created_at: :desc).to_a
      @issues = MaintenanceVisit.where(service_request_id: @requests.map(&:id), kind: "client_issue").includes(:team_member).order(created_at: :desc).to_a
    end
  end
end
