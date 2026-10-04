# Payment to collect once an installation is completed (cashier task)
class Payment < ApplicationRecord
  STATUSES = %w[pending received].freeze

  belongs_to :service_request
  belongs_to :team_member, optional: true

  validates :status, inclusion: { in: STATUSES }
  validates :amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :amount, presence: true, numericality: { greater_than: 0 }, if: -> { status == "received" }

  def receive!(amount:, note: nil)
    transaction do
      update!(status: "received", amount: amount, received_on: Date.current, note: note.to_s.strip.presence)
      req = service_request
      req.updates.create!(status: req.status, progress: req.progress, team_member: team_member,
                          note: "Payment received: ₹#{self.amount.to_i}")
    end
  end
end
