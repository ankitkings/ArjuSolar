class ChatMembership < ApplicationRecord
  belongs_to :chat
  belongs_to :member, polymorphic: true, optional: true
end
