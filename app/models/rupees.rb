# Formats money the Indian way: ₹1,85,000
module Rupees
  PATTERN = /(\d+?)(?=(\d\d)+(\d)(?!\d))/

  def self.display(amount)
    return "—" if amount.nil?
    value = amount.to_d
    text = value.frac.zero? ? value.to_i.to_s : Kernel.format("%.2f", value)
    "₹#{ActiveSupport::NumberHelper.number_to_delimited(text, delimiter_pattern: PATTERN)}"
  end
end
