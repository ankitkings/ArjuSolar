module Admin
  class ChatsController < BaseController
    include ChatActions

    private

    def chat_user = current_admin
    def chat_namespace = "admin"
  end
end
