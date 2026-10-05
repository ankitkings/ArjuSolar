# One receipt per amount the cashier collects against a Payment
class Receipt < ApplicationRecord
  MODES = {
    "cash" => "Cash", "upi" => "UPI", "bank_transfer" => "Bank transfer",
    "cheque" => "Cheque", "card" => "Card"
  }.freeze

  belongs_to :payment
  belongs_to :team_member, optional: true

  validates :amount, numericality: { greater_than: 0 }
  validates :mode, inclusion: { in: MODES.keys }
  validates :received_on, presence: true
  validate :not_more_than_balance, on: :create

  after_create :assign_number

  def mode_label = MODES[mode]

  # Total received up to and including this receipt
  def paid_to_date
    payment.receipts.where("receipts.id <= ?", id).sum(:amount)
  end

  def balance_after
    payment.amount_due && payment.amount_due - paid_to_date
  end

  private

  def not_more_than_balance
    balance = payment&.balance
    if balance && amount && amount > balance
      errors.add(:amount, "is more than the balance due (#{Rupees.display(balance)})")
    end
  end

  def assign_number
    update_column(:number, format("RCT-%d-%05d", created_at.year, id))
  end
end
