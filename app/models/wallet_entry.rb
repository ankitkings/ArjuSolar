# One line of the wallet: money in (+) or out (-)
class WalletEntry < ApplicationRecord
  KINDS = { "deposit" => "Money added", "withdrawal" => "Money taken out", "order" => "Parts ordered", "order_refund" => "Order cancelled",
            "salary" => "Salary paid", "salary_refund" => "Salary payment removed", "client_payment" => "Payment from a client" }.freeze

  validates :kind, inclusion: { in: KINDS.keys }
  validates :amount, numericality: { other_than: 0 }
  validates :happened_on, presence: true

  # the same event is written only once
  def self.record!(kind:, amount:, label:, source: nil, on: Date.current)
    attrs = { kind: kind, source_type: source&.class&.name, source_id: source&.id }
    find_by(attrs) || create!(attrs.merge(amount: amount, label: label, happened_on: on))
  end

  def kind_label = KINDS[kind]
end
