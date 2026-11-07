Rails.application.config.to_prepare do
  Staff::TasksController.include(CompletedWorkSection) unless Staff::TasksController.include?(CompletedWorkSection)
end
