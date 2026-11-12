# The bill of a payment: the installed items with their prices, what was paid and what is still due.
# When the payment is complete (every cheque confirmed by the bank) it is the FINAL bill.
class Bill
  Line = Struct.new(:description, :quantity, :unit, :unit_price, :amount, keyword_init: true)

  attr_reader :payment, :service_request, :installation, :quote

  def initialize(payment)
    @payment = payment
    @service_request = payment.service_request
    @installation = @service_request.installation
    @quote = @service_request.accepted_quote
  end

  def number = payment.bill_number
  def final? = payment.fully_paid?
  def total = payment.amount_due.to_d
  def receipts = @receipts ||= payment.receipts.order(:id).to_a
  def paid = payment.amount_paid.to_d
  def balance = [total - paid, 0].max
  def waiting_cheques = receipts.select(&:waiting_for_bank?)

  # the installed items
  def lines
    @lines ||=
      if quote && quote.quote_items.any?
        quote.quote_items.order(:position, :id).map do |item|
          Line.new(description: item.description, quantity: item.quantity, unit: item.unit, unit_price: item.unit_price, amount: item.line_total)
        end
      elsif quote
        [Line.new(description: quote.system_name.presence || "Solar system#{" #{format('%g', quote.capacity_kw)} kW" if quote.capacity_kw}",
                  quantity: 1, unit_price: quote.list_price, amount: quote.list_price)]
      else
        [Line.new(description: "Solar system installation#{" – #{installation.summary}" if installation}", quantity: 1, unit_price: total, amount: total)]
      end
  end

  def subtotal = lines.sum(&:amount)
  def discount = quote ? quote.discount.to_d : 0
  def adjustment = total - (subtotal - discount)   # the admin changed the amount after the quotation

  # GST: the prices are taken as including GST; this shows how much of the total it is
  def gst_rate = SiteSetting.current.gst_rate.to_d
  def gst? = gst_rate.positive?
  def gst_amount = (total * gst_rate / (100 + gst_rate)).round(2)
  def taxable_value = total - gst_amount
  def half_gst = (gst_amount / 2).round(2)

  def fully_paid_on
    done = receipts.select(&:counted?)
    done.map { |r| [r.received_on, r.cleared_on].compact.max }.max
  end
end
