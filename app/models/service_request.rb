class ServiceRequest < ApplicationRecord
  STATUSES = %w[pending contacted site_visit quote_sent installation completed cancelled].freeze

  # Progress follows the status. "cancelled" keeps the progress it had.
  STATUS_PROGRESS = {
    "pending" => 0, "contacted" => 10, "site_visit" => 30,
    "quote_sent" => 50, "installation" => 75, "completed" => 100
  }.freeze

  belongs_to :team_member, optional: true
  has_many :updates, -> { order(created_at: :desc) }, class_name: "RequestUpdate", dependent: :destroy
  has_one :installation, dependent: :destroy
  has_many :maintenance_visits, -> { order(:due_on) }, dependent: :destroy
  has_one :payment, dependent: :destroy

  validates :name, presence: true, length: { maximum: 100 }
  validates :phone, presence: true, format: { with: /\A[+\d][\d\s-]{7,15}\z/, message: "is not a valid number" }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :message, length: { maximum: 2000 }
  validates :status, inclusion: { in: STATUSES }
  validates :progress, numericality: { in: 0..100 }

  before_create :assign_initial_owner
  before_save :sync_progress_with_status

  def status_label = status.humanize
  def stage_department = RequestWorkflow::DEPARTMENT[status]
  def stage_department_label = TeamMember::DEPARTMENTS[stage_department]

  def self.progress_flow
    STATUS_PROGRESS.map { |s, p| "#{s.humanize} #{p}%" }.join(" → ")
  end

  # Move to another stage: progress follows, the next department's least busy
  # member gets the task automatically, and the change is logged in the timeline.
  def advance!(to:, by: nil, admin: nil, note: nil)
    self.status = to
    handover = assign_for_status
    transaction do
      save!
      updates.create!(status: status, progress: progress, team_member: by, admin_user: admin,
                      note: [note.presence, handover].compact.join(" — ").presence)
    end
  end

  # Manual (admin) assignment
  def assign_to!(member, admin: nil, note: nil)
    self.team_member = member
    transaction do
      save!
      who = member ? "Assigned to #{member.name} (#{member.department_label}) by admin" : "Unassigned by admin"
      updates.create!(status: status, progress: progress, admin_user: admin,
                      note: [note.presence, who].compact.join(" — "))
    end
  end

  # Saves the installed system, completes the request and creates the follow-ups:
  # maintenance visits (servicing team, on their due dates) and a payment task (cashier).
  def complete_installation!(inst, by: nil, admin: nil)
    transaction do
      inst.save!
      visits = inst.schedule_maintenance!
      pay = open_payment_task
      notes = ["Installation completed (#{inst.summary})"]
      notes << "maintenance checks scheduled: #{visits.map { |v| v.due_on.strftime('%d %b %Y') }.join(', ')}" if visits.any?
      notes << (pay.team_member ? "payment task assigned to #{pay.team_member.name} (Cashier)" : "payment task created, no active cashier – assign manually")
      advance!(to: "completed", by: by, admin: admin, note: notes.join(" — "))
    end
  end

  # Re-run automatic assignment for the current stage (used by rake requests:reassign)
  def reassign_for_stage!
    handover = assign_for_status
    return unless handover
    transaction do
      save!
      updates.create!(status: status, progress: progress, note: handover)
    end
  end

  private

  def assign_initial_owner
    assign_for_status if team_member_id.nil?
  end

  # Sets team_member for the current status. Returns a note, or nil if nothing changed.
  def assign_for_status
    dept = stage_department
    return nil unless dept                                            # completed / cancelled keep the last person
    return nil if team_member&.active? && team_member.department == dept   # already the right department

    member = TeamMember.least_busy(dept, :service_requests, "service_requests.status IN (#{RequestWorkflow.active_sql})")
    self.team_member = member
    if member
      "Auto-assigned to #{member.name} (#{member.department_label})"
    else
      "No active #{TeamMember::DEPARTMENTS[dept]} member found – please assign manually"
    end
  end

  def open_payment_task
    return payment if payment
    cashier = TeamMember.least_busy("cashier", :payments, "payments.status = 'pending'")
    create_payment!(team_member: cashier)
  end

  def sync_progress_with_status
    self.progress = STATUS_PROGRESS[status] if status_changed? && STATUS_PROGRESS.key?(status)
  end
end
