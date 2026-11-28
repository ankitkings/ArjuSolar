module Admin
  # Admin > Wallet (password protected): the balance of the account. Orders for parts take their amount out of it.
  # It has nothing to do with the earnings report.
  class WalletController < BaseController
    def show
      @wallet = Wallet.current
      @entries = WalletEntry.order(happened_on: :desc, id: :desc).limit(100).to_a
    end

    def setup
      amount = params[:opening_balance].to_s.to_d
      wallet = Wallet.current || Wallet.new
      wallet.assign_attributes(opening_balance: amount, opened_on: Date.current, enabled: true)
      wallet.save!
      redirect_to admin_wallet_path, notice: "The wallet is on, starting with #{helpers.inr(amount)}. Every order for parts now takes its amount out of it."
    end

    # money added to the wallet, or taken out of it
    def entry
      kind = params[:kind] == "withdrawal" ? "withdrawal" : "deposit"
      amount = params[:amount].to_s.to_d
      return redirect_to(admin_wallet_path, alert: "Enter an amount.") unless amount.positive?
      return redirect_to(admin_wallet_path, alert: "Switch the wallet on first.") unless Wallet.on?
      WalletEntry.create!(kind: kind, amount: (kind == "deposit" ? amount : -amount), happened_on: Date.current, label: params[:label].to_s.strip.presence || WalletEntry::KINDS[kind])
      redirect_to admin_wallet_path, notice: "#{WalletEntry::KINDS[kind]}: #{helpers.inr(amount)}."
    end

    def settings
      wallet = Wallet.current
      return redirect_to(admin_wallet_path, alert: "Set up the wallet first.") unless wallet
      wallet.update!(enabled: params[:enabled] == "1", deduct_salaries: params[:deduct_salaries] == "1", add_client_payments: params[:add_client_payments] == "1")
      redirect_to admin_wallet_path, notice: "Saved."
    end
  end
end
