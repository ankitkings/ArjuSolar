# frozen_string_literal: true

# An order placed with a supplier. Any part, any quantity.
class StockOrder < ApplicationRecord
  STATUSES = %w[ordered received cancelled].freeze

  belongs_to :catalog_item

  validates :status, inclusion: { in: STATUSES }
  validates :quantity, numericality: { greater_than: 0 }

  scope :open_orders, -> { where(status: 'ordered') }

  # The parts arrived: they go into stock (the quantity that really came can differ from the order)
  def receive!(received = nil)
    qty = received.to_s.to_d
    qty = quantity unless qty.positive?
    transaction do
      catalog_item.add_stock!(qty, kind: 'received', note: "Order ##{id} received")
      update!(status: 'received', quantity_received: qty, received_on: Date.current)
    end
  end
end
