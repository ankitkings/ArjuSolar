module Admin
  # Admin > Earnings (password protected): what the owner earns, in total and on every installation
  class EarningsController < BaseController
    def show
      @month = parse_month(params[:month])
      @earnings = Earnings.new(@month)
      @history = (0..11).map { |i| Earnings.new(Date.current.beginning_of_month - i.months) }
      @expenses = Expense.where(spent_on: @month..@month.end_of_month).order(:spent_on, :id).to_a
    end

    private

    def parse_month(value)
      Date.strptime(value.to_s, "%Y-%m")
    rescue ArgumentError
      Date.current.beginning_of_month
    end
  end
end
