# The master switch of the government subsidy (Admin > Subsidy switch).
#   ON : subsidy works everywhere: on quotations, system prices, the website, the DISCOM approval / net meter steps, the tracker.
#   OFF: the subsidy is simply left out. Quotations carry none, the website does not mention it, no job waits for DISCOM
#        or the net meter, and nothing else in the process changes.
module SubsidySwitch
  class State < ActiveSupport::CurrentAttributes
    attribute :on
  end

  # texts on the website that only mention the subsidy when it is on (changed only while they are still the original texts)
  NO_SUBSIDY_TEXTS = {
    hero_subtitle: "Affordable, clean and efficient solar for homes and businesses. We plan it, install it and look after it for years.",
    meta_description: "Arju Solars installs rooftop solar for homes and businesses in Indore and Central India: free site visit, installation, service and maintenance."
  }.freeze

  def self.on?
    State.on = SiteSetting.current.subsidy_enabled if State.on.nil?
    State.on
  end

  def self.off? = !on?

  def self.turn_on!
    setting = SiteSetting.current
    setting.subsidy_enabled = true
    NO_SUBSIDY_TEXTS.each { |field, text| setting[field] = SiteSetting::DEFAULTS[field] if setting[field] == text }
    setting.save!
    State.reset
  end

  # Returns how many jobs were waiting for DISCOM or the net meter and were let go on.
  def self.turn_off!(admin:)
    setting = SiteSetting.current
    setting.subsidy_enabled = false
    NO_SUBSIDY_TEXTS.each { |field, text| setting[field] = text if setting[field] == SiteSetting::DEFAULTS[field] }
    setting.save!
    State.reset

    released = 0
    ServiceRequest.where(installation_status: "waiting_for_approval").find_each { |request| request.release_installation!(admin: admin); released += 1 }
    ServiceRequest.where(installation_status: "waiting_for_net_meter").find_each { |request| request.release_payment!(admin: admin); released += 1 }
    released
  end
end
