Rails.application.config.to_prepare do
  Staff::TasksController.include(CompletedWorkSection) unless Staff::TasksController.include?(CompletedWorkSection)
  Staff::TasksController.include(CreateRequestButton) unless Staff::TasksController.include?(CreateRequestButton)
end
