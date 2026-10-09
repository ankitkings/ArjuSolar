class CreateChats < ActiveRecord::Migration[7.1]
  def change
    # a conversation: a group (shared "Everyone" or a custom one) or a personal chat between two people
    create_table :chats do |t|
      t.string :kind, null: false          # "group" or "direct"
      t.string :name                       # groups only
      t.string :direct_key                 # personal chats: one chat per pair of people
      t.string :system_key                 # "everyone" for the shared group
      t.timestamps
    end
    add_index :chats, :direct_key, unique: true
    add_index :chats, :system_key, unique: true

    # who is in a chat. A person is an admin (AdminUser) or a teammate (TeamMember).
    create_table :chat_memberships do |t|
      t.references :chat, null: false, foreign_key: true
      t.string :member_type, null: false
      t.bigint :member_id, null: false
      t.bigint :last_read_message_id       # everything up to here is read
      t.timestamps
    end
    add_index :chat_memberships, %i[chat_id member_type member_id], unique: true, name: "index_chat_memberships_uniqueness"
    add_index :chat_memberships, %i[member_type member_id]

    create_table :chat_messages do |t|
      t.references :chat, null: false, foreign_key: true
      t.string :sender_type, null: false
      t.bigint :sender_id, null: false
      t.text :body, null: false
      t.timestamps
    end
    add_index :chat_messages, %i[chat_id id]
  end
end
