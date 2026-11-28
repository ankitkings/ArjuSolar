# What the owner earns. Two views of one month:
#   1. money view: received from clients - parts bought - salaries paid - other expenses
#   2. installation margin: for every installation of the month, what the client pays minus what the parts cost us
class Earnings
  Row = Struct.new(:installation, :request, :total, :parts_cost, :margin, :received, keyword_init: true) do
    def margin_percent = (total.to_d.positive? && margin) ? (margin / total * 100).round(1) : nil
    def balance = total ? [total - received, 0].max : nil
  end

  attr_reader :from, :to

  def initialize(month)
    @from = month.beginning_of_month
    @to = month.end_of_month
  end

  def received
    Receipt.where(clearing_status: [nil, "cleared"]).where("COALESCE(receipts.cleared_on, receipts.received_on) BETWEEN ? AND ?", from, to).sum(:amount).to_d
  end

  def parts_bought
    StockOrder.where(status: "received", received_on: from..to).includes(:catalog_item).sum do |order|
      (order.quantity_received || order.quantity).to_d * (order.unit_cost || order.catalog_item.cost_price).to_d
    end
  end

  def salaries = SalaryPayment.where(paid_on: from..to).sum(:net_amount).to_d
  def other_expenses = Expense.where(spent_on: from..to).sum(:amount).to_d

  # money view
  def owner_cash = received - parts_bought - salaries - other_expenses

  def rows
    @rows ||= Installation.where(installed_on: from..to).includes(service_request: %i[payment quotes]).order(:installed_on, :id).map do |installation|
      request = installation.service_request
      payment = request.payment
      total = payment&.amount_due&.to_d
      cost = parts_cost(request, installation)
      Row.new(installation: installation, request: request, total: total, parts_cost: cost, margin: (total && cost ? total - cost : nil),
              received: (payment ? payment.amount_paid.to_d : 0.to_d))
    end
  end

  def margin_total = rows.sum { |row| row.margin.to_d }
  def billed_total = rows.sum { |row| row.total.to_d }

  # installation margin view: margin of the month's installations - salaries - other expenses
  def owner_from_installations = margin_total - salaries - other_expenses

  private

  def parts_cost(request, installation)
    quote = request.accepted_quote
    if quote && quote.quote_items.any?
      quote.quote_items.sum { |item| item.quantity.to_d * (item.cost_price || item.catalog_item&.cost_price || 0).to_d }
    elsif installation.solar_package
      installation.solar_package.package_items.includes(:catalog_item).sum { |item| item.quantity.to_d * item.catalog_item.cost_price.to_d }
    end
  end
end
