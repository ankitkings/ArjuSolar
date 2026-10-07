# A price quotation made after the site visit. Either a ready-made system from the package list,
# or a custom quote built from individual parts (quote_items) with their own prices.
# Everything is copied onto the quote, so later price changes never alter it.
class Quote < ApplicationRecord
  STATUSES = %w[sent accepted declined superseded].freeze
  DEFAULT_VALIDITY_DAYS = 15
  DEFAULT_COUNTRY_CODE = "91"   # added to 10-digit Indian numbers for WhatsApp

  belongs_to :service_request
  belongs_to :solar_package, optional: true
  belongs_to :team_member, optional: true
  has_many :quote_items, -> { order(:position, :id) }, dependent: :destroy, inverse_of: :quote
  has_secure_token :public_token   # secret link for the client (older quotes get theirs on first use)

  before_validation :set_defaults
  before_validation :copy_from_package, on: :create
  before_validation :compute_from_items
  before_validation :calculate_total

  validates :solar_package, presence: { message: "must be selected" }, on: :create, unless: -> { quote_items.any? }
  validates :list_price, numericality: { greater_than: 0 }
  validates :discount, numericality: { greater_than_or_equal_to: 0 }
  validates :valid_until, presence: true
  validates :status, inclusion: { in: STATUSES }
  validate :discount_not_more_than_price
  validate :package_has_price, on: :create
  validate :custom_needs_panel_and_inverter

  after_create :assign_number

  def ensure_public_token!
    regenerate_public_token if public_token.blank?
    public_token
  end

  # "+91 98270 45612" / "098270 45612" / "9827045612" -> "919827045612" (digits only, with country code)
  def self.whatsapp_number(phone)
    digits = phone.to_s.gsub(/\D/, "").sub(/\A0+/, "")
    digits = "#{DEFAULT_COUNTRY_CODE}#{digits}" if digits.length == 10
    digits
  end

  def whatsapp_message(link, sender_name = nil, pdf_link: nil)
    lines = ["Hello #{service_request.name},",
             "this is #{sender_name.presence || 'the team'} from Arju Solars. Here is your solar quotation #{number}:",
             "",
             "System: #{system_name} (#{format('%g', capacity_kw.to_f)} kW)",
             "Total: #{Rupees.display(total)}#{" (after a discount of #{Rupees.display(discount)})" if discount.positive?}",
             "Valid until: #{valid_until.strftime('%d %b %Y')}",
             "",
             (pdf_link ? "Your quotation (PDF): #{pdf_link}\nView online: #{link}" : "View / download your quotation: #{link}"),
             "",
             "Please reply here if you have any questions. Thank you!"]
    lines.join("\n")
  end

  # opens WhatsApp to the client's number with the message ready to send
  def whatsapp_url(link, sender_name = nil, pdf_link: nil)
    "https://wa.me/#{self.class.whatsapp_number(service_request.phone)}?text=#{ERB::Util.url_encode(whatsapp_message(link, sender_name, pdf_link: pdf_link))}"
  end

  # built from individual parts (not from a ready-made package)
  def custom? = quote_items.any?
  def expired? = status == "sent" && valid_until < Date.current

  def details
    "#{format('%g', capacity_kw.to_f)} kW · #{panel_count} panels · #{panel_brand} · Inverter #{inverter_model}"
  end

  private

  def set_defaults
    self.discount = 0 if discount.nil?
    self.valid_until ||= Date.current + DEFAULT_VALIDITY_DAYS
  end

  def copy_from_package
    return unless solar_package
    self.system_name    = solar_package.name
    self.capacity_kw    = solar_package.capacity_kw
    self.panel_count    = solar_package.panel_count
    self.panel_brand    = solar_package.panel_brand
    self.inverter_model = solar_package.inverter_model
    self.list_price     = solar_package.price
  end

  # Custom quote: price = sum of all lines; capacity / panel count / brands come from the chosen parts
  def compute_from_items
    items = quote_items.to_a
    return if items.empty?
    items.each(&:prepare)
    panels    = items.select { |i| i.category == "panel" }
    inverters = items.select { |i| i.category == "inverter" }
    self.list_price     = items.sum { |i| i.line_total || 0 }
    self.panel_count    = panels.sum { |i| i.quantity.to_i }
    self.capacity_kw    = panels.sum { |i| (i.quantity || 0) * (i.capacity_kw || 0) }.round(2)
    self.panel_brand    = panels.map(&:description).uniq.join(" + ").presence
    self.inverter_model = inverters.map(&:description).uniq.join(" + ").presence
    self.system_name    = system_name.presence || "Custom solar system"
  end

  def calculate_total
    self.total = list_price - discount if list_price && discount
  end

  def discount_not_more_than_price
    errors.add(:discount, "cannot be more than the price") if list_price && discount && discount > list_price
  end

  def package_has_price
    errors.add(:solar_package, "has no price yet – set it in Admin → Systems") if solar_package && solar_package.price.nil?
  end

  def custom_needs_panel_and_inverter
    items = quote_items.to_a
    return if items.empty?
    categories = items.map(&:category)
    errors.add(:base, "Add at least one solar panel and one inverter") unless categories.include?("panel") && categories.include?("inverter")
    errors.add(:base, "The chosen panel has no capacity (kW) in the parts price list") if categories.include?("panel") && capacity_kw.to_f <= 0
  end

  def assign_number
    update_column(:number, format("QT-%d-%05d", created_at.year, id))
  end
end
