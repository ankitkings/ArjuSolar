class TeamMember < ApplicationRecord
  DEPARTMENTS = {
    "contact_person"  => "Contact Person",
    "site_visitor"    => "Site Visitor",
    "installation"    => "Installation Team",
    "daily_servicing" => "Daily Servicing",
    "cashier"         => "Cashier Department"
  }.freeze

  has_secure_password validations: false   # login is optional per member

  has_many :service_requests, dependent: :nullify
  has_many :request_updates, dependent: :nullify
  has_many :maintenance_visits, dependent: :nullify
  has_many :payments, dependent: :nullify

  before_validation { self.email = email.to_s.strip.downcase.presence }

  validates :name, presence: true
  validates :department, inclusion: { in: DEPARTMENTS.keys }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: true, allow_nil: true
  validates :password, length: { minimum: 8 }, allow_nil: true

  after_commit :pick_up_waiting_requests, on: %i[create update]

  scope :public_listed, -> { where(active: true, show_on_website: true).order(:name) }

  # Active member of a department with the fewest open tasks (ties -> lowest id).
  # open_condition is a fixed SQL snippet (never user input).
  def self.least_busy(department, association, open_condition)
    where(department: department, active: true)
      .left_joins(association)
      .group("team_members.id")
      .order(Arel.sql("COUNT(CASE WHEN #{open_condition} THEN 1 END)"), :id)
      .take
  end

  def department_label = DEPARTMENTS[department]
  def can_login? = active? && email.present? && password_digest.present?

  private

  # Requests that reached a stage while its department had nobody available stay unassigned.
  # As soon as an active member exists for that department, they are handed over automatically.
  def pick_up_waiting_requests
    return unless active?
    statuses = RequestWorkflow::DEPARTMENT.select { |_status, dept| dept == department }.keys
    return if statuses.empty?
    ServiceRequest.where(status: statuses, team_member_id: nil).find_each(&:reassign_for_stage!)
  end
end
