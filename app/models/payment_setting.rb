# Where clients can pay us: our UPI id and our bank account (Admin > Payment setup)
class PaymentSetting < ApplicationRecord
  UPI_FORMAT = /\A[\w.\-]{2,256}@[A-Za-z][A-Za-z0-9]{1,63}\z/
  IFSC_FORMAT = /\A[A-Z]{4}0[A-Z0-9]{6}\z/

  before_validation do
    self.upi_id = upi_id.to_s.strip.presence
    self.ifsc = ifsc.to_s.strip.upcase.presence
    self.account_number = account_number.to_s.gsub(/\s+/, "").presence
  end

  validates :upi_id, format: { with: UPI_FORMAT, message: "is not a valid UPI id (like name@bank)" }, allow_nil: true
  validates :ifsc, format: { with: IFSC_FORMAT, message: "is not a valid IFSC code" }, allow_nil: true
  validates :account_number, format: { with: /\A\d{6,20}\z/, message: "must be 6 to 20 digits" }, allow_nil: true

  def self.current = first || create!

  def upi_ready? = upi_id.present?
  def bank_ready? = account_number.present? && ifsc.present? && account_name.present?

  # The link a UPI app understands. Shown as a QR code and as a button.
  def upi_link(amount:, note: nil)
    fields = [["pa", upi_id], ["pn", upi_name.presence || "Arju Solars"], ["am", format("%.2f", amount)], ["cu", "INR"], ["tn", note]]
    "upi://pay?" + fields.reject { |_, value| value.blank? }.map { |key, value| "#{key}=#{key == 'pa' ? value : ERB::Util.url_encode(value.to_s)}" }.join("&")
  end
end
