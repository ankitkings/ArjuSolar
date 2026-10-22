# frozen_string_literal: true

# Parts set aside for one scheduled installation
class StockReservation < ApplicationRecord
  belongs_to :service_request
  belongs_to :catalog_item

  validates :quantity, numericality: { greater_than: 0 }
end
