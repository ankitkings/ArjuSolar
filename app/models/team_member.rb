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
  has_many :quotes, dependent: :nullify
  has_many :receipts, dependent: :nullify
  has_many :chat_memberships, as: :member, dependent: :destroy

  before_validation { self.email = email.to_s.strip.downcase.presence }

  validates :name, presence: true
  validates :department, inclusion: { in: DEPARTMENTS.keys }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: true, allow_nil: true
  validates :password, length: { minimum: 8 }, allow_nil: true

  after_commit :pick_up_waiting_requests, on: %i[create update]

  scope :public_listed, -> { where(active: true, show_on_website: true).order(:name) }

  # Active member of a department with the fewest active tasks (ties -> longest-serving member)
  def self.least_busy(department)
    members = where(department: department, active: true).order(:id).to_a
    return nil if members.empty?
    counts = active_task_counts
    members.min_by { |m| [counts[m.id], m.id] }
  end

  # id => number of active tasks (requests in progress + assigned maintenance visits)
  def self.active_task_counts
    counts = Hash.new(0)
    ServiceRequest.where(status: RequestWorkflow::ACTIVE_STATUSES).where.not(team_member_id: nil)
                  .group(:team_member_id).count.each { |id, n| counts[id] += n }
    MaintenanceVisit.where(status: "assigned").group(:team_member_id).count.each { |id, n| counts[id] += n }
    counts
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
