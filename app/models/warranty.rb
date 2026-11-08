# How long a client can ask for a visit when something is wrong with the system.
# It starts on the installation date and runs for the months set in Admin > Clients.
module Warranty
  def self.months = PortalSetting.current.warranty_months

  def self.ends_on(installation)
    installation.installed_on + months.months
  end

  def self.active?(installation, on: Date.current)
    installation.present? && on <= ends_on(installation)
  end

  def self.days_left(installation, on: Date.current)
    (ends_on(installation) - on).to_i
  end
end
