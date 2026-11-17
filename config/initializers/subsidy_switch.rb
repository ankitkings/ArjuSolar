# While the subsidy is switched off, a quotation and a system carry no subsidy, whatever is stored in them.
# Nothing is deleted: switch it on again and the old figures are back.
module SubsidyOffForQuote
  def subsidy_applies = SubsidySwitch.on? && super
  def subsidy_applies? = SubsidySwitch.on? && super
  def subsidy_amount = SubsidySwitch.on? ? super : 0
end

module SubsidyOffForPackage
  def subsidy_amount = SubsidySwitch.on? ? super : 0
  def effective_cost = SubsidySwitch.on? ? super : price
end

Rails.application.config.to_prepare do
  Quote.prepend(SubsidyOffForQuote) unless Quote.include?(SubsidyOffForQuote)
  SolarPackage.prepend(SubsidyOffForPackage) unless SolarPackage.include?(SubsidyOffForPackage)
end
