# frozen_string_literal: true

class StockMovement < ApplicationRecord
  KINDS = %w[received used adjustment].freeze
  KIND_LABELS = { 'received' => 'Received', 'used' => 'Used on a job', 'adjustment' => 'Count corrected' }.freeze

  belongs_to :catalog_item
  belongs_to :service_request, optional: true

  validates :kind, inclusion: { in: KINDS }
  validates :quantity, numericality: { other_than: 0 }

  def kind_label = KIND_LABELS[kind]
end
