# What the cashier must enter for each way of paying, the checks on it, and how it is shown afterwards.
#   cash          -> how many notes of each value (a counting machine can fill these in later)
#   cheque        -> cheque number, bank, date, name on the cheque
#   upi           -> transaction id (the QR code is shown on the payment page)
#   bank_transfer -> NEFT / RTGS / IMPS / DBT with the UTR and the sender's details
#   card          -> card machine (POS) approval: last 4 digits, approval code. Never the full number or the PIN.
module PaymentMethods
  NOTES = [2000, 500, 200, 100, 50, 20, 10].freeze
  TRANSFER_TYPES = %w[NEFT RTGS IMPS DBT Other].freeze
  CARD_TYPES = %w[Debit Credit].freeze
  CARD_NETWORKS = %w[Visa Mastercard RuPay Amex Other].freeze
  UPI_APPS = ["Google Pay", "PhonePe", "Paytm", "BHIM", "Amazon Pay", "Other"].freeze
  CHEQUE_MAX_AGE_DAYS = 90
  REFERENCE_FORMAT = /\A[A-Za-z0-9]{8,35}\z/

  Result = Struct.new(:details, :reference, :errors, keyword_init: true)

  def self.build(mode, raw, amount:, today: Date.current)
    raw = {} unless raw.respond_to?(:to_unsafe_h) || raw.is_a?(Hash)   # anything else sent by mistake is ignored
    data = (raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw.to_h).with_indifferent_access
    case mode
    when "cash"          then cash(data, amount)
    when "cheque"        then cheque(data, today)
    when "upi"           then upi(data)
    when "bank_transfer" then bank_transfer(data, today)
    when "card"          then card(data)
    else Result.new(details: {}, reference: nil, errors: ["Choose how the client is paying."])
    end
  end

  # ---------------- cash ----------------
  def self.cash(data, amount)
    errors = []
    notes = {}
    NOTES.each do |value|
      text = data.dig(:notes, value.to_s).to_s.strip
      count = text.empty? ? 0 : (Integer(text, 10) rescue nil)
      if count.nil? || count.negative?
        errors << "The number of ₹#{value} notes must be a whole number."
        count = 0
      end
      notes[value.to_s] = count
    end
    coin_text = data[:coins].to_s.strip
    coins = coin_text.empty? ? 0 : (Integer(coin_text, 10) rescue nil)
    if coins.nil? || coins.negative?
      errors << "Coins must be a whole number of rupees."
      coins = 0
    end

    total = notes.sum { |value, count| value.to_i * count } + coins
    if errors.empty?
      if total.zero?
        errors << "Count the cash first: enter how many notes of each value the client gave."
      elsif total < amount
        errors << "The counted cash (#{Rupees.display(total)}) is less than the amount received (#{Rupees.display(amount)}). Count again or reduce the amount."
      end
    end
    details = { "notes" => notes.select { |_, count| count.positive? }, "coins" => coins, "counted_total" => total,
                "change_returned" => [total - amount, 0].max.to_f.round(2), "counted_by" => data[:counted_by] == "machine" ? "machine" : "manual" }
    Result.new(details: details, reference: nil, errors: errors)
  end

  # ---------------- cheque ----------------
  def self.cheque(data, today)
    errors = []
    number = text(data, :cheque_no)
    errors << "Enter the 6-digit cheque number." unless number.match?(/\A\d{6}\z/)
    errors << "Enter the bank name of the cheque." if text(data, :bank).blank?
    errors << "Enter the name written on the cheque (account holder)." if text(data, :drawer).blank?
    ifsc = text(data, :ifsc).upcase
    errors << "The IFSC code is not valid." if ifsc.present? && !ifsc.match?(PaymentSetting::IFSC_FORMAT)
    date = parse_date(text(data, :cheque_date))
    if date.nil?
      errors << "Enter the date written on the cheque."
    elsif date > today
      errors << "This cheque is post-dated (#{date.strftime('%d %b %Y')}) – it cannot be received before that date."
    elsif date < today - CHEQUE_MAX_AGE_DAYS
      errors << "This cheque is older than 3 months – it is no longer valid."
    end
    details = { "cheque_no" => number, "bank" => text(data, :bank), "branch" => text(data, :branch), "ifsc" => ifsc,
                "cheque_date" => date&.iso8601, "drawer" => text(data, :drawer) }.compact_blank
    Result.new(details: details, reference: number.presence, errors: errors)
  end

  # ---------------- UPI ----------------
  def self.upi(data)
    errors = []
    txn = text(data, :txn_id)
    errors << "Enter the UPI transaction id (UTR) of the payment." unless txn.match?(REFERENCE_FORMAT)
    payer = text(data, :payer_upi)
    errors << "The client's UPI id is not valid (like name@bank)." if payer.present? && !payer.match?(PaymentSetting::UPI_FORMAT)
    errors << "Tick the box after you have seen the money arrive in our account." unless data[:verified] == "1"
    details = { "txn_id" => txn, "payer_upi" => payer, "app" => text(data, :app) }.compact_blank
    Result.new(details: details, reference: txn.presence, errors: errors)
  end

  # ---------------- bank transfer / DBT ----------------
  def self.bank_transfer(data, today)
    errors = []
    type = text(data, :transfer_type)
    errors << "Choose the type of transfer (NEFT, RTGS, IMPS, DBT)." unless TRANSFER_TYPES.include?(type)
    utr = text(data, :utr)
    errors << "Enter the UTR / transaction reference of the transfer." unless utr.match?(REFERENCE_FORMAT)
    errors << "Enter the name of the client's bank." if text(data, :from_bank).blank?
    errors << "Enter the name of the account holder who sent the money." if text(data, :from_holder).blank?
    last4 = text(data, :from_last4)
    errors << "The last 4 digits of the account must be 4 numbers." if last4.present? && !last4.match?(/\A\d{4}\z/)
    date = parse_date(text(data, :transfer_date))
    if date.nil? then errors << "Enter the date of the transfer."
    elsif date > today then errors << "The transfer date cannot be in the future."
    end
    errors << "Tick the box after you have seen the money arrive in our account." unless data[:verified] == "1"
    details = { "transfer_type" => type, "utr" => utr, "from_bank" => text(data, :from_bank), "from_holder" => text(data, :from_holder),
                "from_last4" => last4, "transfer_date" => date&.iso8601 }.compact_blank
    Result.new(details: details, reference: utr.presence, errors: errors)
  end

  # ---------------- card (POS machine) ----------------
  def self.card(data)
    errors = []
    errors << "Choose debit or credit card." unless CARD_TYPES.include?(text(data, :card_type))
    errors << "Choose the card network (Visa, Mastercard, RuPay …)." unless CARD_NETWORKS.include?(text(data, :network))
    errors << "Enter the last 4 digits of the card." unless text(data, :last4).match?(/\A\d{4}\z/)
    approval = text(data, :approval_code)
    errors << "Enter the approval code printed on the card machine slip." unless approval.match?(/\A[A-Za-z0-9]{4,12}\z/)
    rrn = text(data, :rrn)
    errors << "The RRN on the slip must be 6 to 16 digits." if rrn.present? && !rrn.match?(/\A\d{6,16}\z/)
    errors << "A card payment can be recorded only when the machine showed APPROVED." unless data[:approved] == "1"
    details = { "card_type" => text(data, :card_type), "network" => text(data, :network), "last4" => text(data, :last4),
                "approval_code" => approval, "rrn" => rrn, "issuer" => text(data, :issuer) }.compact_blank
    Result.new(details: details, reference: approval.presence, errors: errors)
  end

  # ---------------- showing it again ----------------
  # [[note value, count, amount], ...] biggest note first
  def self.cash_lines(details)
    (details || {}).with_indifferent_access.fetch(:notes, {}).map { |value, count| [value.to_i, count.to_i, value.to_i * count.to_i] }.sort_by { |value, _, _| -value }
  end

  # label / value pairs for every mode except cash
  def self.rows(mode, details)
    d = (details || {}).with_indifferent_access
    list =
      case mode
      when "cheque" then [["Cheque no.", d[:cheque_no]], ["Bank", d[:bank]], ["Branch", d[:branch]], ["IFSC", d[:ifsc]], ["Cheque date", date_text(d[:cheque_date])], ["Name on cheque", d[:drawer]]]
      when "upi" then [["UPI transaction id (UTR)", d[:txn_id]], ["Client's UPI id", d[:payer_upi]], ["Paid with", d[:app]]]
      when "bank_transfer" then [["Transfer type", d[:transfer_type]], ["UTR", d[:utr]], ["Sent from bank", d[:from_bank]], ["Account holder", d[:from_holder]], ["Account (last 4)", d[:from_last4]], ["Transfer date", date_text(d[:transfer_date])]]
      when "card" then [["Card", [d[:card_type], d[:network]].compact_blank.join(" ")], ["Card number", d[:last4].present? ? "•••• •••• •••• #{d[:last4]}" : nil], ["Approval code", d[:approval_code]], ["RRN", d[:rrn]], ["Issuing bank", d[:issuer]]]
      else []
      end
    list.reject { |_, value| value.blank? }
  end

  # one short line for lists
  def self.summary(mode, details)
    d = (details || {}).with_indifferent_access
    case mode
    when "cash"
      parts = cash_lines(d).map { |value, count, _| "₹#{value} × #{count}" }
      parts << "coins ₹#{d[:coins]}" if d[:coins].to_i.positive?
      line = parts.join(", ")
      line += " · change returned #{Rupees.display(d[:change_returned])}" if d[:change_returned].to_f.positive?
      line
    when "cheque" then "Cheque #{d[:cheque_no]} · #{d[:bank]}"
    when "upi" then "UTR #{d[:txn_id]}#{" · #{d[:app]}" if d[:app].present?}"
    when "bank_transfer" then "#{d[:transfer_type]} · UTR #{d[:utr]} · #{d[:from_bank]}"
    when "card" then "#{d[:card_type]} #{d[:network]} •••• #{d[:last4]} · approval #{d[:approval_code]}"
    else ""
    end
  end

  def self.text(data, key) = data[key].to_s.strip

  def self.parse_date(value)
    Date.iso8601(value)
  rescue ArgumentError, TypeError
    nil
  end

  def self.date_text(value)
    parse_date(value.to_s)&.strftime("%d %b %Y") || value
  end
end
