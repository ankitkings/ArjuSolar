# Money the business spends besides salaries and parts: rent, fuel, electricity ...
class Expense < ApplicationRecord
  validates :spent_on, :label, presence: true
  validates :label, length: { maximum: 100 }
  validates :amount, numericality: { greater_than: 0 }
  validate { errors.add(:spent_on, "cannot be in the future") if spent_on && spent_on > Date.current }
end
