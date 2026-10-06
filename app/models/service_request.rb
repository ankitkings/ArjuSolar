class ServiceRequest < ApplicationRecord
  STATUSES = %w[pending contacted site_visit quote_sent installation payment commissioning completed cancelled].freeze

  # Progress follows the status. A cancelled deal goes back to 0.
  # payment = installation done, waiting for the money; commissioning = paid, panels get started + final touch.
  STATUS_PROGRESS = {
    "pending" => 0, "contacted" => 10, "site_visit" => 30, "quote_sent" => 50,
    "installation" => 75, "payment" => 85, "commissioning" => 95, "completed" => 100,
    "cancelled" => 0
  }.freeze

  belongs_to :team_member, optional: true
  has_many :updates, -> { order(created_at: :desc) }, class_name: "RequestUpdate", dependent: :destroy
  has_many :quotes, -> { order(:created_at, :id) }, dependent: :destroy
  has_one :installation, dependent: :destroy
  has_many :maintenance_visits, -> { order(:due_on) }, dependent: :destroy
  has_one :payment, dependent: :destroy

  validates :name, presence: true, length: { maximum: 100 }
  validates :phone, presence: true, format: { with: /\A[+\d][\d\s-]{7,15}\z/, message: "is not a valid number" }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :message, length: { maximum: 2000 }
  validates :address, presence: true, length: { maximum: 500 }, on: :create
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
    from = status
    self.status = to
    self.final_touch_due_on = Date.current + 1 if to == "commissioning"   # same day or the next day
    handover = assign_for_status
    transaction do
      save!
      quote_followup(from, to)
      open_payment_task(agreed_amount_for(installation)) if to == "payment" && installation && payment.nil?
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
      sync_payment_owner
      updates.create!(status: status, progress: progress, admin_user: admin,
                      note: [note.presence, who].compact.join(" — "))
    end
  end

  def latest_quote = quotes.reorder(id: :desc).first
  def accepted_quote = quotes.where(status: "accepted").reorder(id: :desc).first

  # Site visitor: make a quote from the price list. On the first quote the request
  # moves to "Quote sent"; a later quote replaces the earlier one.
  def create_quote!(package:, discount: nil, valid_until: nil, notes: nil, by: nil)
    transaction do
      quotes.where(status: "sent").update_all(status: "superseded")
      quote = quotes.create!(solar_package: package, discount: discount.presence, valid_until: valid_until.presence,
                             notes: notes.to_s.strip.presence, team_member: by)
      text = "Quote #{quote.number} created: #{quote.system_name}, #{Rupees.display(quote.total)}"
      text += " (after a discount of #{Rupees.display(quote.discount)})" if quote.discount.positive?
      if status == "site_visit"
        advance!(to: "quote_sent", by: by, note: text)
      else
        updates.create!(status: status, progress: progress, team_member: by, note: text)
      end
      quote
    end
  end

  # What the client has to pay: the accepted quote, if it is for the system that was installed
  def agreed_amount_for(inst)
    q = accepted_quote
    q && q.solar_package_id == inst.solar_package_id ? q.total : inst.package_price
  end

  # The installer finishes: saves the installed system (with site photos), schedules the
  # maintenance checks and hands the request to a cashier (payment stage, 85%).
  # When the cashier has received the full amount, Payment#collect! moves it on to Daily Servicing (95%).
  def complete_installation!(inst, by: nil, admin: nil)
    transaction do
      inst.save!
      visits = inst.schedule_maintenance!
      amount = agreed_amount_for(inst)
      notes = ["Installation done (#{inst.summary})"]
      notes << "payment of #{Rupees.display(amount)} to be collected" if amount
      notes << "maintenance checks scheduled: #{visits.map { |v| v.due_on.strftime('%d %b %Y') }.join(', ')}" if visits.any?
      advance!(to: "payment", by: by, admin: admin, note: notes.join(" — "))
      open_payment_task(amount)
    end
  end

  # Re-run automatic assignment for the current stage (used by rake requests:reassign)
  def reassign_for_stage!
    handover = assign_for_status
    return unless handover
    transaction do
      save!
      sync_payment_owner
      updates.create!(status: status, progress: progress, note: handover)
    end
  end

  private

  # Keeps the quote in step with the request: accepted when installation starts,
  # declined when the request is cancelled at the quote stage.
  def quote_followup(from, to)
    quote = latest_quote
    return unless quote && quote.status == "sent"
    quote.update!(status: "accepted") if to == "installation"
    quote.update!(status: "declined") if to == "cancelled" && from == "quote_sent"
  end

  def assign_initial_owner
    assign_for_status if team_member_id.nil?
  end

  # Sets team_member for the current status. Returns a note, or nil if nothing changed.
  def assign_for_status
    dept = stage_department
    return nil unless dept                                            # completed / cancelled keep the last person
    return nil if team_member&.active? && team_member.department == dept   # already the right department

    member = TeamMember.least_busy(dept)
    self.team_member = member
    if member
      "Auto-assigned to #{member.name} (#{member.department_label})"
    else
      "No active #{TeamMember::DEPARTMENTS[dept]} member found – please assign manually"
    end
  end

  def open_payment_task(price = nil)
    return payment if payment
    cashier = team_member if team_member&.department == "cashier"   # the cashier who owns the payment stage
    cashier ||= TeamMember.least_busy("cashier")
    create_payment!(team_member: cashier, amount_due: price)
  end

  # The payment always belongs to the cashier who owns the request at the payment stage
  def sync_payment_owner
    return unless status == "payment" && payment && team_member&.department == "cashier"
    payment.update!(team_member: team_member) unless payment.team_member_id == team_member_id
  end

  def sync_progress_with_status
    self.progress = STATUS_PROGRESS[status] if status_changed? && STATUS_PROGRESS.key?(status)
  end
end
