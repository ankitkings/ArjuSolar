# Rules of the client portal (Admin > Clients)
class PortalSetting < ApplicationRecord
  validates :warranty_months, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 360 }

  def self.current = first || create!
end
