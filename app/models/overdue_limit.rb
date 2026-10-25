# How many days a step may take, as changed by the admin (Admin > Overdue)
class OverdueLimit < ApplicationRecord
  validates :key, presence: true, uniqueness: true
  validates :days, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 365 }

  # every step with its days: the standard ones, replaced by what the admin saved
  def self.all_limits
    defaults = OverdueSteps.defaults
    defaults.merge(pluck(:key, :days).to_h.slice(*defaults.keys))
  end
end
