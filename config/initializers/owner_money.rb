# Parts orders, salaries and client payments move the wallet by themselves (while the wallet is switched on).
Rails.application.config.to_prepare do
  StockOrder.class_eval do
    after_create { Wallet.charge_order!(self) }
    after_update { Wallet.refund_order!(self) if saved_change_to_status? && status == "cancelled" }
  end

  SalaryPayment.class_eval do
    after_create { Wallet.charge_salary!(self) }
    after_destroy { Wallet.refund_salary!(self) }
  end

  Receipt.class_eval do
    after_create { Wallet.credit_receipt!(self) if counted? }                                              # cash, UPI ... count at once
    after_update { Wallet.credit_receipt!(self) if saved_change_to_clearing_status? && clearing_status == "cleared" }   # a cheque counts when the bank has it
  end
end
