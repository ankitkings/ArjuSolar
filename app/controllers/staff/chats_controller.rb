module Staff
  class ChatsController < BaseController
    include ChatActions

    private

    def chat_user = current_staff
    def chat_namespace = "staff"
  end
end
