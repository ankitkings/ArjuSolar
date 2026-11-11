# The admin's own to-do list: everything that is waiting for the admin.
# "New" = it arrived after the admin last opened Admin > My tasks.
class AdminTasks
  Task = Struct.new(:kind, :title, :detail, :since, :record, :fresh, keyword_init: true)
  KIND_LABELS = { "subsidy" => "PM Surya Ghar", "hold" => "Job on hold", "leave" => "Leave request", "order" => "Parts to order", "salary" => "Salary", "cheque" => "Cheque" }.freeze

  def self.for(admin)
    seen = admin.tasks_seen_at
    unless seen   # first time: nothing counts as new
      seen = Time.current
      admin.update_column(:tasks_seen_at, seen)
    end
    new(seen)
  end

  def self.mark_seen!(admin) = admin.update_column(:tasks_seen_at, Time.current)

  def initialize(seen_at)
    @seen_at = seen_at
  end

  # new ones first, then the one that has waited longest
  def tasks = (@tasks ||= build.sort_by { |t| [t.fresh ? 0 : 1, t.since] })
  def count = tasks.size
  def new_count = tasks.count(&:fresh)

  private

  def build
    list = []

    # PM Surya Ghar applications that are not finished: the admin makes / follows each step on the portal
    applications = SubsidyApplication.in_group("in_progress").includes(:service_request).to_a
    applications.each do |application|
      request = application.service_request
      held = request.assigned_to_admin?
      since = held ? (request.admin_assigned_at || application.updated_at) : application.updated_at
      detail = application.next_step
      detail += " – the job is on hold until this is done" if held
      list << task("subsidy", "#{request.name} – #{application.status_label}", detail, since, application)
    end

    # requests handed to the admin that have no subsidy application to show them
    ServiceRequest.where(assigned_to_admin: true).where.not(id: applications.map(&:service_request_id)).each do |request|
      reason = request.installation_status == "waiting_for_net_meter" ? "Installation done – waiting for the net meter step" : "Waiting for the subsidy approval"
      list << task("hold", "#{request.name} – job on hold", reason, request.admin_assigned_at || request.updated_at, request)
    end

    LeaveRequest.pending.includes(:team_member).each do |leave|
      dates = leave.from_date == leave.to_date ? leave.from_date.strftime("%d %b") : "#{leave.from_date.strftime('%d %b')} – #{leave.to_date.strftime('%d %b')}"
      list << task("leave", "#{leave.team_member.name} – #{leave.kind_label}", "#{dates} (#{leave.days} #{'day'.pluralize(leave.days)}): #{leave.reason}", leave.created_at, leave)
    end

    # the salaries of last month that are worked out but not paid yet
    last_month = Date.current.beginning_of_month - 1.month
    payroll = Payroll.new(last_month)
    paid_ids = SalaryPayment.where(month: last_month).pluck(:team_member_id)
    unpaid = TeamMember.where(active: true).where.not(monthly_salary: nil).where.not(id: paid_ids).select { |member| payroll.summary(member).earned.to_d.positive? }
    if unpaid.any?
      list << task("salary", "Pay the salaries of #{last_month.strftime('%B %Y')}",
                   "#{unpaid.size} #{'employee'.pluralize(unpaid.size)} not paid yet: #{unpaid.first(3).map(&:name).to_sentence}#{' and more' if unpaid.size > 3}",
                   Date.current.beginning_of_month.beginning_of_day, last_month)
    end

    # cheques taken from clients that the bank has not confirmed yet
    waiting = Receipt.waiting_for_bank.includes(:payment).order(:id).to_a
    if waiting.any?
      list << task("cheque", "#{waiting.size} #{'cheque'.pluralize(waiting.size)} waiting for the bank",
                   "Confirm whether the bank received #{waiting.size == 1 ? 'it' : 'them'}: #{Rupees.display(waiting.sum(&:amount))} in total", waiting.first.created_at, waiting.first.payment)
    end

    lines = RequiredParts.new.order_lines
    list << Task.new(kind: "order", title: "Order #{lines.size} #{'part'.pluralize(lines.size)}", detail: "Short for jobs or below the minimum level",
                     since: Time.current, record: :order, fresh: false) if lines.any?
    list
  end

  def task(kind, title, detail, since, record)
    Task.new(kind: kind, title: title, detail: detail, since: since, record: record, fresh: since > @seen_at)
  end
end
