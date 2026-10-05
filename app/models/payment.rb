# What the client owes for an installed system, and what has been collected so far.
# Every amount collected creates a numbered Receipt (so a client can pay in instalments).
class Payment < ApplicationRecord
  STATUSES = %w[pending partial received].freeze   # received = fully paid

  belongs_to :service_request
  belongs_to :team_member, optional: true   # the cashier responsible
  has_many :receipts, -> { order(:created_at, :id) }, dependent: :destroy

  validates :status, inclusion: { in: STATUSES }
  validates :amount_due, numericality: { greater_than: 0 }, allow_nil: true

  def amount_paid
    receipts.loaded? ? receipts.sum(&:amount) : receipts.sum(:amount)
  end

  def balance
    amount_due && [amount_due - amount_paid, 0].max
  end

  def fully_paid? = status == "received"

  # Records money received, creates its receipt and updates the status + request timeline.
  def collect!(amount:, mode:, reference: nil, note: nil, by: nil, received_on: Date.current)
    transaction do
      receipt = receipts.create!(
        amount: amount, mode: mode, reference: reference.to_s.strip.presence, note: note.to_s.strip.presence,
        received_on: received_on, team_member: by || team_member
      )
      refresh_status!
      req = service_request
      text = "Receipt #{receipt.number}: #{Rupees.display(receipt.amount)} received (#{receipt.mode_label})"
      text += ". Balance #{Rupees.display(balance)}" if balance
      req.updates.create!(status: req.status, progress: req.progress, team_member: receipt.team_member, note: text)
      receipt
    end
  end

  def refresh_status!
    paid = amount_paid
    self.status = if paid.zero? then "pending"
                  elsif amount_due && paid >= amount_due then "received"
                  else "partial"
                  end
    save!
  end
end
