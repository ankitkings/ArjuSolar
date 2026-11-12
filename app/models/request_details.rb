# The extra details asked on the installation request forms (website and staff), written as the message of the request
class RequestDetails
  PROPERTY_TYPES = ["Home / independent house", "Apartment / society", "Shop / office", "Factory / industry", "Farm / agriculture", "School / institution", "Other"].freeze
  BILLS = ["Below ₹1,500", "₹1,500 – ₹3,000", "₹3,000 – ₹6,000", "₹6,000 – ₹10,000", "Above ₹10,000", "Not sure"].freeze
  ROOFS = ["RCC flat roof", "Tin / metal shed", "Tile / sloped roof", "Open land / ground", "Not sure"].freeze

  def self.compose(params, extra_lines: [])
    lines = []
    lines << "Property: #{params[:property]}" if PROPERTY_TYPES.include?(params[:property])
    lines << "Monthly electricity bill: #{params[:bill]}" if BILLS.include?(params[:bill])
    lines << "Roof: #{params[:roof]}" if ROOFS.include?(params[:roof])
    package = SolarPackage.available.find_by(id: params[:package_id])
    lines << "Interested in: #{package.label}" if package
    visit = (Date.iso8601(params[:visit_on].to_s) rescue nil)
    lines << "Preferred site-visit date: #{visit.strftime('%d %b %Y')}" if visit && visit.between?(Date.current, Date.current + 60)
    notes = params[:notes].to_s.strip.first(1000)
    lines << "Notes: #{notes}" if notes.present?
    (lines + extra_lines).join("\n")
  end
end
