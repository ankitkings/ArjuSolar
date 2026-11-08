# A client who registered on the website. The e-mail address is the login.
# A client gets a link by e-mail to set the password, and another one if the password is forgotten.
class Customer < ApplicationRecord
  PHONE_FORMAT = /\A[+\d][\d\s-]{7,15}\z/
  MAX_FAILED_LOGINS = 5
  LOCK_MINUTES = 15

  has_secure_password validations: false
  has_many :service_requests, dependent: :nullify

  # links in the e-mails; they stop working as soon as the password changes
  generates_token_for(:password, expires_in: 3.days) { password_digest&.last(10) }
  generates_token_for(:password_reset, expires_in: 2.hours) { password_digest&.last(10) }

  before_validation do
    self.email = email.to_s.strip.downcase.presence
    self.name = name.to_s.strip
    self.phone = phone.to_s.strip
    self.phone_key = Customer.phone_key_for(phone)
  end

  validates :name, presence: true, length: { maximum: 100 }
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: { case_sensitive: false }
  validates :phone, presence: true, format: { with: PHONE_FORMAT, message: "is not a valid number" }
  validates :password, length: { minimum: 8, maximum: 72 }, confirmation: true, allow_nil: true
  validates :password_confirmation, presence: { message: "must be typed again" }, if: -> { password.present? }

  # the last 10 digits of a phone number: "+91 98765-43210" and "9876543210" are the same number
  def self.phone_key_for(phone) = phone.to_s.gsub(/\D/, "").last(10)

  # The client profile a request belongs to: the same e-mail, or the same phone number
  # (a phone number counts only when exactly one client has it).
  def self.match_for(email:, phone:)
    address = email.to_s.strip.downcase
    found = address.present? ? find_by(email: address) : nil
    return found if found
    key = phone_key_for(phone)
    return nil if key.length < 10
    matches = where(phone_key: key).limit(2).to_a
    matches.size == 1 ? matches.first : nil
  end

  # The client profile of the person who sent a request: the existing one with the same e-mail, or a new one made from
  # the name, e-mail and phone he gave. No e-mail is sent; the admin can send the set-password link later.
  # Without an e-mail address no profile can be made (nil).
  def self.ensure_for_request(service_request)
    address = service_request.email.to_s.strip.downcase
    return nil if address.blank?
    existing = find_by(email: address)
    return existing if existing
    profile = create(name: service_request.name, email: address, phone: service_request.phone, auto_created: true)
    profile.persisted? ? profile : nil
  end

  # One-time conversion of the requests already in the database. Returns [profiles made, requests linked, requests without e-mail].
  def self.backfill_from_requests!
    made = 0
    linked = 0
    ServiceRequest.where(customer_id: nil).where.not(email: [nil, ""]).order(:id).find_each do |service_request|
      address = service_request.email.to_s.strip.downcase
      profile = find_by(email: address)
      unless profile
        profile = create(name: service_request.name, email: address, phone: service_request.phone, auto_created: true)
        made += 1 if profile.persisted?
      end
      next unless profile.persisted?
      service_request.update_columns(customer_id: profile.id)
      linked += 1
    end
    find_each(&:link_existing_requests!)   # requests that carry only the same phone number
    [made, linked, ServiceRequest.where(customer_id: nil).count]
  end

  def self.find_by_link_token(token)
    find_by_token_for(:password, token) || find_by_token_for(:password_reset, token)
  end

  def password_set? = password_digest.present?
  def locked? = locked_until.present? && locked_until.future?
  def first_name = name.to_s.split.first

  def register_failure!
    attempts = failed_attempts + 1
    if attempts >= MAX_FAILED_LOGINS
      update_columns(failed_attempts: 0, locked_until: LOCK_MINUTES.minutes.from_now)
    else
      update_columns(failed_attempts: attempts)
    end
  end

  def sign_in!
    update_columns(failed_attempts: 0, locked_until: nil, last_login_at: Time.current)
    link_existing_requests!
  end

  # Requests made earlier (contact form or admin) with this e-mail or phone number belong to the client.
  # Returns how many were linked.
  def link_existing_requests!
    conditions = ["LOWER(email) = :email"]
    values = { email: email }
    if phone_key.to_s.length >= 10 && Customer.where(phone_key: phone_key).where.not(id: id).none?
      conditions << "phone_key = :key"
      values[:key] = phone_key
    end
    ServiceRequest.where(customer_id: nil).where(conditions.join(" OR "), values).update_all(customer_id: id)
  end
end
