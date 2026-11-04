# When a chat is opened, remember where the person stopped reading so the page can show what is new:
# a "New messages" line at that spot, the new messages highlighted, and the chat opened right there.
# (Added on top of ChatActions; only the "show" step is different.)
module ChatNewMessages
  extend ActiveSupport::Concern

  def show
    load_sidebar
    @chat = find_chat
    membership = @chat.memberships.find_by(member_type: chat_user.class.name, member_id: chat_user.id)
    @last_read_id = membership&.last_read_message_id.to_i        # everything up to here was read before
    @messages = @chat.messages.includes(:sender).order(:id).last(200)

    # messages from other people that came after the last one this person read
    # (the first time a chat is opened nothing counts as "new")
    from_others = @chat.messages.where("chat_messages.id > ?", @last_read_id)
                       .where.not(sender_type: chat_user.class.name, sender_id: chat_user.id)
    @unread_total = @last_read_id.positive? ? from_others.count : 0
    @first_unread_id = if @unread_total.positive?
      @messages.find { |m| m.id > @last_read_id && !(m.sender_type == chat_user.class.name && m.sender_id == chat_user.id) }&.id
    end

    mark_read(@chat)
    render "chats/show"
  end
end
