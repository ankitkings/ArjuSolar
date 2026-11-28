module Admin
  # other expenses of the business (rent, fuel, electricity ...), counted in the earnings
  class ExpensesController < BaseController
    def create
      expense = Expense.new(params.require(:expense).permit(:spent_on, :label, :amount, :note))
      month = (expense.spent_on || Date.current).strftime("%Y-%m")
      if expense.save
        redirect_to admin_earnings_path(month: month), notice: "Expense saved."
      else
        redirect_to admin_earnings_path(month: month), alert: expense.errors.full_messages.to_sentence
      end
    end

    def destroy
      expense = Expense.find(params[:id])
      expense.destroy
      redirect_to admin_earnings_path(month: expense.spent_on.strftime("%Y-%m")), notice: "Expense removed."
    end
  end
end
