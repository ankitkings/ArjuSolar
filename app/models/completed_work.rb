# Everything a team member has finished, newest first:
#   - steps: a request moved on by them (site visit done -> quote sent, installation done -> payment, ...)
#   - maintenance visits they marked done
#   - payments they collected (cashier)
class CompletedWork
  Item = Struct.new(:at, :kind, :title, :detail, :record, keyword_init: true)
  ICONS = { "step" => "✅", "visit" => "🛠️", "payment" => "💰" }.freeze

  def initialize(member)
    @member = member
  end

  def all = (@all ||= (steps + visits + receipts).sort_by { |item| -item.at.to_f })
  def latest(count = 15) = all.first(count)
  def total = all.size

  def today = all.count { |item| local_date(item) == Date.current }
  def this_week = all.count { |item| local_date(item) >= Date.current.beginning_of_week }
  def this_month = all.count { |item| local_date(item) >= Date.current.beginning_of_month }

  # items finished in one month
  def in_month(month)
    first = month.beginning_of_month
    all.select { |item| local_date(item).beginning_of_month == first }
  end

  # [[first day of month, how many], ...] newest first
  def months
    all.map { |item| local_date(item).beginning_of_month }.tally.sort.reverse
  end

  private

  def local_date(item) = item.at.in_time_zone.to_date

  # a step = an update written by this person that changed the status of the request
  def steps
    mine = RequestUpdate.where(team_member_id: @member.id).includes(:service_request).order(:created_at).to_a
    return [] if mine.empty?
    history = RequestUpdate.where(service_request_id: mine.map(&:service_request_id).uniq)
                           .order(:service_request_id, :created_at, :id).pluck(:id, :service_request_id, :status)
    previous = {}
    last = {}
    history.each do |id, request_id, status|
      previous[id] = last[request_id]
      last[request_id] = status
    end
    mine.filter_map do |update|
      before = previous[update.id]
      next if before.nil? || before == update.status || before == "payment"   # not a step; the cashier's work shows as payments
      request = update.service_request
      Item.new(at: update.created_at, kind: "step", title: "#{before.humanize} done → #{update.status.humanize}",
               detail: "#{request&.name} · request ##{update.service_request_id}", record: request)
    end
  end

  def visits
    MaintenanceVisit.where(team_member_id: @member.id, status: "done").includes(:service_request).map do |visit|
      report = visit.report.to_s.strip
      Item.new(at: visit.completed_at || visit.updated_at, kind: "visit", title: "Maintenance visit done – #{visit.title}",
               detail: [visit.service_request&.name, report.presence&.truncate(80)].compact.join(" · "), record: visit)
    end
  end

  def receipts
    Receipt.where(team_member_id: @member.id).includes(payment: :service_request).map do |receipt|
      Item.new(at: receipt.created_at, kind: "payment", title: "Payment collected – #{Rupees.display(receipt.amount)} (#{receipt.mode_label})",
               detail: "#{receipt.payment.service_request.name} · #{receipt.number}", record: receipt)
    end
  end
end
