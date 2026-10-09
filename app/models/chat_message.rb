class ChatMessage < ApplicationRecord
  belongs_to :chat, touch: true   # a new message moves the chat to the top of the list
  belongs_to :sender, polymorphic: true, optional: true

  validates :body, presence: true, length: { maximum: 2000 }

  # { chat_id => number of messages this person has not read yet }
  def self.unread_counts_for(user)
    join_sql = sanitize_sql_array(["INNER JOIN chat_memberships cm ON cm.chat_id = chat_messages.chat_id AND cm.member_type = ? AND cm.member_id = ?",
                                   user.class.name, user.id])
    joins(join_sql)
      .where("chat_messages.id > COALESCE(cm.last_read_message_id, 0)")
      .where.not(sender_type: user.class.name, sender_id: user.id)
      .group("chat_messages.chat_id").count
  end
end
