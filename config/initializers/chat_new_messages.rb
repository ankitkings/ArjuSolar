Rails.application.config.to_prepare do
  [Admin::ChatsController, Staff::ChatsController].each do |controller|
    controller.include(ChatNewMessages) unless controller.include?(ChatNewMessages)
  end
end
