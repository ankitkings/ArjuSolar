# The admin's own to-do list: everything that is waiting for the admin.
# "New" = it arrived after the admin last opened Admin > My tasks.
class AdminTasks
  Task = Struct.new(:kind, :title, :detail, :since, :record, :fresh, keyword_init: true)
  KIND_LABELS = { "subsidy" => "PM Surya Ghar", "hold" => "Job on hold", "leave" => "Leave request", "order" => "Parts to order" }.freeze

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

    lines = RequiredParts.new.order_lines
    list << Task.new(kind: "order", title: "Order #{lines.size} #{'part'.pluralize(lines.size)}", detail: "Short for jobs or below the minimum level",
                     since: Time.current, record: :order, fresh: false) if lines.any?
    list
  end

  def task(kind, title, detail, since, record)
    Task.new(kind: kind, title: title, detail: detail, since: since, record: record, fresh: since > @seen_at)
  end
end
