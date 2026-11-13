Rails.application.config.to_prepare do
  Admin::ServiceRequestsController.prepend(RequestSearch) unless Admin::ServiceRequestsController.include?(RequestSearch)
end
