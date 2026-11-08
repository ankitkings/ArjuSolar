# What the client reads about each stage of the request (no internal notes)
module PortalStatus
  STEPS = {
    "pending"       => ["Request received", "We have your request and will call you soon."],
    "contacted"     => ["We contacted you", "Our team has spoken to you about your requirement."],
    "site_visit"    => ["Site visit", "Our engineer visits your place to check the roof and take measurements."],
    "quote_sent"    => ["Quotation", "Your quotation is ready. Please have a look and let us know."],
    "installation"  => ["Installation", "Your system is being arranged and installed."],
    "payment"       => ["Payment", "The installation is done. The payment is now due."],
    "commissioning" => ["Starting your system", "Payment received. We are starting your system and giving the final touch."],
    "completed"     => ["Your solar system is live", "Your system is installed and running. Enjoy clean energy!"]
  }.freeze

  def self.title(status) = STEPS.fetch(status, [status.to_s.humanize]).first
  def self.text(status) = STEPS.fetch(status, ["", ""]).last
  def self.track = ServiceRequest::STATUSES - ["cancelled"]
end
