# Everything that has been in a step longer than it should: shown on the dashboard, high priority first.
class OverdueSteps
  Item = Struct.new(:priority, :title, :detail, :due_at, :owner, :record, keyword_init: true) do
    def high? = priority == "High"
  end

  # days a request may stay in a step before it is overdue (twice as long = high priority)
  LIMITS = { "pending" => 1, "contacted" => 2, "site_visit" => 3, "quote_sent" => 5,
             "installation" => 3, "payment" => 7, "final_touch" => 2 }.freeze
  HOLD_LIMITS = { "waiting_for_stock" => 2, "waiting_for_approval" => 10, "waiting_for_net_meter" => 7 }.freeze
  HOLD_LABELS = { "waiting_for_stock" => "Installation waiting for parts", "waiting_for_approval" => "Installation waiting for the electricity company",
                  "waiting_for_net_meter" => "Waiting for the net meter (before payment)" }.freeze
  SUBSIDY_LIMITS = { "preparing" => 3, "applied" => 15, "net_meter_applied" => 15, "commissioned" => 7, "bank_submitted" => 30 }.freeze

  def items = (@items ||= build.sort_by { |i| [i.high? ? 0 : 1, i.due_at] })
  def count = items.size
  def high_count = items.count(&:high?)

  private

  def build
    now = Time.current
    requests = ServiceRequest.where(status: LIMITS.keys).includes(:team_member).to_a
    entered = RequestUpdate.where(service_request_id: requests.map(&:id)).group(:service_request_id, :status).minimum(:created_at)
    list = requests.filter_map { |r| request_item(r, entered[[r.id, r.status]] || r.created_at, now) }
    list + maintenance_items(now) + subsidy_items(now)
  end

  # at most one item per request: the most serious thing that is late
  def request_item(request, since, now)
    today = Date.current
    if request.status == "installation" && request.installation_status == "scheduled" && request.installation_scheduled_on && request.installation_scheduled_on < today
      return item("High", request, "Installation date missed", "It was planned for #{request.installation_scheduled_on.strftime('%d %b')}", request.installation_scheduled_on.end_of_day)
    end
    if request.status == "final_touch" && request.final_touch_due_on && request.final_touch_due_on < today
      return item("High", request, "Panel start-up / final touch is late", "It was due on #{request.final_touch_due_on.strftime('%d %b')}", request.final_touch_due_on.end_of_day)
    end
    if request.status == "quote_sent" && (quote = request.latest_quote) && quote.expired?
      return item("Medium", request, "Quote expired", "Quote #{quote.number} was valid until #{quote.valid_until.strftime('%d %b')} – ask the client or revise it", quote.valid_until.end_of_day)
    end

    held = request.status == "installation" && HOLD_LIMITS[request.installation_status]
    limit = held || LIMITS[request.status]
    due_at = since + limit.days
    return nil unless now > due_at

    title = held ? HOLD_LABELS[request.installation_status] : "#{request.status_label} is taking too long"
    priority = now > since + (limit * 2).days ? "High" : "Medium"
    item(priority, request, title, "In this step since #{since.strftime('%d %b')}; it should take about #{limit} #{'day'.pluralize(limit)}", due_at)
  end

  def item(priority, request, title, detail, due_at)
    Item.new(priority: priority, title: "#{request.name} – #{title}", detail: detail, due_at: due_at, owner: request.owner_label, record: request)
  end

  def maintenance_items(now)
    MaintenanceVisit.where(status: %w[scheduled assigned]).where("due_on < ?", Date.current).includes(:service_request, :team_member).map do |visit|
      Item.new(priority: visit.due_on < 7.days.ago.to_date ? "High" : "Medium",
               title: "#{visit.service_request.name} – maintenance visit overdue",
               detail: "#{visit.title}, due #{visit.due_on.strftime('%d %b')}", due_at: visit.due_on.end_of_day,
               owner: visit.team_member&.name || "Unassigned", record: visit.service_request)
    end
  end

  def subsidy_items(now)
    SubsidyApplication.where(status: SUBSIDY_LIMITS.keys).includes(:service_request).filter_map do |app|
      limit = SUBSIDY_LIMITS[app.status]
      due_at = app.updated_at + limit.days
      next unless now > due_at
      Item.new(priority: now > app.updated_at + (limit * 2).days ? "High" : "Medium",
               title: "#{app.service_request.name} – subsidy: #{app.status_label}",
               detail: app.next_step, due_at: due_at, owner: "Admin", record: app)
    end
  end
end
