# The business wallet (account balance): an opening balance plus every entry.
# Orders for parts take their total out of it. This is separate from the earnings (profit) report.
class Wallet < ApplicationRecord
  def self.current = first
  def self.on? = first&.enabled? || false

  def balance = opening_balance.to_d + WalletEntry.sum(:amount)

  # --- the things that move the wallet by themselves (only while it is switched on) ---
  def self.charge_order!(order)
    return unless on?
    total = order.unit_cost.to_d * order.quantity.to_d
    return if total.zero?
    WalletEntry.record!(kind: "order", amount: -total, label: "Order: #{format('%g', order.quantity)} × #{order.catalog_item.name}", source: order)
  end

  def self.refund_order!(order)
    return unless on?
    charged = WalletEntry.find_by(kind: "order", source_type: "StockOrder", source_id: order.id)
    return unless charged
    WalletEntry.record!(kind: "order_refund", amount: -charged.amount, label: "Order cancelled: #{order.catalog_item.name}", source: order)
  end

  def self.charge_salary!(payment)
    return unless current&.enabled? && current.deduct_salaries?
    WalletEntry.record!(kind: "salary", amount: -payment.net_amount, label: "Salary: #{payment.member_name}, #{payment.month_label}", source: payment, on: payment.paid_on)
  end

  def self.refund_salary!(payment)
    charged = WalletEntry.find_by(kind: "salary", source_type: "SalaryPayment", source_id: payment.id)
    return unless charged
    WalletEntry.record!(kind: "salary_refund", amount: -charged.amount, label: "Salary payment removed: #{payment.member_name}, #{payment.month_label}", source: payment)
  end

  def self.credit_receipt!(receipt)
    return unless current&.enabled? && current.add_client_payments?
    WalletEntry.record!(kind: "client_payment", amount: receipt.amount, label: "Receipt #{receipt.number}", source: receipt)
  end
end
