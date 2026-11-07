# One phone number, WhatsApp number, e-mail address or address shown on the website (Admin > Website)
class ContactEntry < ApplicationRecord
  KINDS = { "phone" => "Phone number", "whatsapp" => "WhatsApp number", "email" => "E-mail address", "address" => "Address" }.freeze
  ICONS = { "phone" => "📞", "whatsapp" => "💬", "email" => "✉️", "address" => "📍" }.freeze

  scope :active, -> { where(active: true) }
  scope :listed, -> { order(:position, :id) }

  before_validation do
    self.value = value.to_s.strip
    self.label = label.to_s.strip.presence
  end

  validates :kind, inclusion: { in: KINDS.keys }
  validates :value, presence: true, length: { maximum: 300 }
  validates :label, length: { maximum: 60 }, allow_nil: true
  validate :value_fits_the_kind

  def kind_label = KINDS[kind]
  def icon = ICONS[kind]
  def digits = value.to_s.gsub(/\D/, "")

  # the number with country code, digits only (a 10-digit Indian number gets 91 in front)
  def full_number
    d = digits.sub(/\A0+/, "")
    d.length == 10 ? "91#{d}" : d
  end

  def href
    case kind
    when "phone" then "tel:+#{full_number}"
    when "whatsapp" then "https://wa.me/#{full_number}"
    when "email" then "mailto:#{value}"
    end
  end

  private

  def value_fits_the_kind
    case kind
    when "phone", "whatsapp"
      errors.add(:value, "must be a phone number with 8 to 15 digits") unless digits.length.between?(8, 15)
    when "email"
      errors.add(:value, "is not a valid e-mail address") unless value.match?(URI::MailTo::EMAIL_REGEXP)
    end
  end
end
