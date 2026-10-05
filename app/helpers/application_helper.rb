module ApplicationHelper
  def inr(amount)
    Rupees.display(amount)
  end
end
