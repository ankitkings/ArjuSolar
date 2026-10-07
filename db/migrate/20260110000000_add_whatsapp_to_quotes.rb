class AddWhatsappToQuotes < ActiveRecord::Migration[7.1]
  def change
    add_column :quotes, :public_token, :string      # secret link the client opens from WhatsApp
    add_index :quotes, :public_token, unique: true
    add_column :quotes, :whatsapp_sent_at, :datetime
  end
end
