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
  has_one :subsidy_application, dependent: :destroy
  has_many :stock_reservations, dependent: :destroy
  has_many :stock_movements, dependent: :nullify

  validates :name, presence: true, length: { maximum: 100 }
  validates :phone, presence: true, format: { with: /\A[+\d][\d\s-]{7,15}\z/, message: "is not a valid number" }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :message, length: { maximum: 2000 }
  validates :address, presence: true, length: { maximum: 500 }, on: :create
  validates :status, inclusion: { in: STATUSES }
  validates :progress, numericality: { in: 0..100 }

  before_create :assign_initial_owner
  before_save :sync_progress_with_status
  before_save :clear_admin_assignment

  def status_label = status.humanize
  def owner_label = assigned_to_admin? ? "Admin" : (team_member&.name || "—")
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
      withdraw_subsidy_application(to)
      open_payment_task(agreed_amount_for(installation)) if to == "payment" && installation && payment.nil?
      plan = plan_installation(from, to)   # parts + installer + date when the quote was accepted
      updates.create!(status: status, progress: progress, team_member: by, admin_user: admin,
                      note: [note.presence, plan || handover].compact.join(" — ").presence)
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
  # `package:` = a ready-made system; `items:` = [[catalog_item, quantity], ...] for a custom quote
  def create_quote!(package: nil, items: [], system_name: nil, discount: nil, valid_until: nil, notes: nil, subsidy_applies: false, extra_items: [], by: nil)
    transaction do
      quotes.where(status: "sent").update_all(status: "superseded")
      if package && items.empty?   # a ready-made system: list every part with its price
        items = package.package_items.includes(:catalog_item).map { |pi| [pi.catalog_item, pi.quantity] } + extra_items   # extras, e.g. a battery
      end
      quote = quotes.build(solar_package: package, system_name: system_name.to_s.strip.presence,
                           discount: discount.presence, valid_until: valid_until.presence,
                           notes: notes.to_s.strip.presence, subsidy_applies: subsidy_applies, team_member: by)
      items.each_with_index { |(catalog_item, qty), i| quote.quote_items.build(catalog_item: catalog_item, quantity: qty, position: i) }
      quote.save!
      text = "Quote #{quote.number} created: #{quote.system_name}, #{Rupees.display(quote.total)}"
      text += " (#{quote.quote_items.size} parts listed)" if quote.quote_items.any?
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
    same = q && (inst.quote_id == q.id || (q.solar_package_id && q.solar_package_id == inst.solar_package_id))
    same ? q.total : inst.package_price
  end

  # The quote includes the government subsidy and the client's documents are not all collected yet
  def subsidy_documents_pending?
    quote = latest_quote
    quote.present? && quote.status == "sent" && quote.subsidy_applies && !subsidy_application&.documents_complete?
  end

  def missing_subsidy_documents
    (subsidy_application || SubsidyApplication.new).missing_documents
  end

  # Jobs that cannot go on yet
  INSTALLATION_WAITING = %w[waiting_for_stock waiting_for_approval waiting_for_net_meter].freeze
  def installation_waiting? = INSTALLATION_WAITING.include?(installation_status)

  # Quotes with the government subsidy: the installation may only start after the application was
  # made on the portal and the electricity company approved it ("DISCOM approved") ...
  def installation_hold_reason
    subsidy_hold_reason("feasibility_approved", "Waiting for the PM Surya Ghar application to be made on the portal and approved by the electricity company")
  end

  # ... and the payment only starts once the status is "Installed, net meter applied".
  def payment_hold_reason
    subsidy_hold_reason("net_meter_applied", "Waiting for the subsidy application to show \"Installed, net meter applied\"")
  end

  # Admin: do not wait any longer
  def release_installation!(admin: nil)
    return unless installation_status == "waiting_for_approval"
    note = InstallationScheduler.new(self).call
    updates.create!(status: status, progress: progress, admin_user: admin,
                    note: "Installation released by the admin without waiting for the approval. #{note}")
  end

  def release_payment!(admin: nil)
    return unless installation_status == "waiting_for_net_meter"
    advance!(to: "payment", admin: admin, note: "Payment started by the admin without waiting for the net meter")
  end

  # [[catalog_item, quantity], ...] the accepted quote needs from stock (services are not stocked)
  def required_parts
    quote = accepted_quote
    return [] unless quote
    totals = Hash.new(0)
    quote.quote_items.includes(:catalog_item).each { |qi| totals[qi.catalog_item] += qi.quantity if qi.catalog_item&.tracks_stock? }
    totals.to_a
  end

  # A blank installation form, pre-filled from the client's address and the accepted quote
  def new_installation
    q = accepted_quote
    Installation.new(installed_on: Date.current, site_address: address,
                     solar_package_id: q&.solar_package_id, quote_id: (q.id if q&.custom?))
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
      if (reason = payment_hold_reason)   # subsidy quotes: payment waits for "Installed, net meter applied"
        update!(installation_status: "waiting_for_net_meter", team_member: nil, assigned_to_admin: true, admin_assigned_at: Time.current)
        updates.create!(status: status, progress: progress, team_member: by, admin_user: admin,
                        note: (notes + ["#{reason}. The request is now with the Admin; the payment starts as soon as that status is set."]).join(" — "))
      else
        advance!(to: "payment", by: by, admin: admin, note: notes.join(" — "))
        open_payment_task(amount)
      end
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

  def subsidy_hold_reason(step, message)
    return nil unless accepted_quote&.subsidy_applies
    application = subsidy_application
    return nil if application&.status == "withdrawn"   # the client is not taking the subsidy
    return nil if application&.reached?(step)
    message
  end

  def start_subsidy_application_if_needed
    return unless accepted_quote&.subsidy_applies && subsidy_application.nil?
    SubsidyApplication.start_for!(self)
    association(:subsidy_application).reset
  end

  # Accepted quote -> reserve parts and book the date. Installation done -> the parts are used.
  # Cancelled / moved back -> the parts are free again for other jobs.
  def plan_installation(from, to)
    if to == "installation"
      start_subsidy_application_if_needed
      if (reason = installation_hold_reason)   # subsidy quotes: wait for the electricity company
        update_columns(installation_status: "waiting_for_approval", installation_scheduled_on: nil, team_member_id: nil, assigned_to_admin: true, admin_assigned_at: Time.current)
        "#{reason}. The request is now with the Admin; the installation is scheduled automatically as soon as the electricity company approves."
      else
        InstallationScheduler.new(self).call
      end
    elsif from == "installation"
      if to == "payment"
        stock_reservations.includes(:catalog_item).each do |r|
          r.catalog_item.add_stock!(-r.quantity, kind: "used", request: self, note: "Used in the installation of request ##{id}")
        end
      end
      stock_reservations.destroy_all
      update_columns(installation_status: nil)
      InstallationScheduler.process_waiting! unless to == "payment"
      nil
    end
  end

  # a cancelled deal has no subsidy application any more
  def withdraw_subsidy_application(to)
    return unless to == "cancelled" && subsidy_application && !subsidy_application.finished?
    subsidy_application.update!(status: "withdrawn")
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

  # giving a request to a teammate takes it away from the Admin
  def clear_admin_assignment
    self.assigned_to_admin = false if team_member_id.present?
  end

  def sync_progress_with_status
    self.progress = STATUS_PROGRESS[status] if status_changed? && STATUS_PROGRESS.key?(status)
  end
end
