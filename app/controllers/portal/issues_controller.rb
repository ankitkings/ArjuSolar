module Portal
  # During the warranty the client can ask for a visit when something is wrong with the system.
  # It becomes a maintenance visit, which the servicing team sees and takes.
  class IssuesController < BaseController
    def create
      service_request = current_customer.service_requests.find(params[:portal_request_id])
      installation = service_request.installation
      back = portal_request_path(service_request, anchor: "issue")

      return redirect_to(back, alert: "There is no installation on this request yet.") unless installation
      unless Warranty.active?(installation)
<<<<<<< Updated upstream
        return redirect_to(back, alert: "The warranty of this system ended on #{Warranty.ends_on(installation).strftime('%d %b %Y')}. Please phone us on #{SiteSetting.current.primary_phone || 'our office'} and we will help you.")
=======
        return redirect_to(back, alert: "The warranty of this system ended on #{Warranty.ends_on(installation).strftime('%d %b %Y')}. Please phone us on +91 7049465926 and we will help you.")
>>>>>>> Stashed changes
      end

      details = params[:details].to_s.strip
      if details.length < 10 || details.length > 1000
        return redirect_to(back, alert: "Please describe the problem in 10 to 1000 characters.")
      end
      if service_request.maintenance_visits.where(kind: "client_issue", status: %w[scheduled assigned]).exists?
        return redirect_to(back, alert: "A visit for your earlier issue is already planned. Our team will come soon – please phone us if it is urgent.")
      end

      day = (Date.iso8601(params[:preferred_on].to_s) rescue nil)
      day = Date.current if day.nil? || day < Date.current
      day = Date.current + 14 if day > Date.current + 14

      service_request.maintenance_visits.create!(installation: installation, title: "Client reported an issue: #{details.truncate(120)}",
                                                 due_on: day, status: "scheduled", kind: "client_issue", issue_details: details)
      service_request.updates.create!(status: service_request.status, progress: service_request.progress,
                                      note: "Client reported an issue (under warranty): #{details.truncate(300)} – site visit asked for #{day.strftime('%d %b %Y')}.")
      MaintenanceVisit.assign_due!
      redirect_to back, notice: "Thank you. Our engineer will visit your site on or after #{day.strftime('%d %b %Y')} to check the problem."
    end
  end
end
