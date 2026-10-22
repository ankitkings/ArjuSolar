# frozen_string_literal: true

# When a client accepts a quote: set the parts aside and book the installation.
#  - parts not in stock          -> the job waits (and shows on the "parts to order" list)
#  - accepted before the cut-off -> can start today, if an installer is free that day
#  - accepted after the cut-off  -> starts the next working day
class InstallationScheduler
  # Called when stock arrives or is freed: waiting jobs are planned in the order they came
  def self.process_waiting!(now: Time.current)
    planned = 0
    ServiceRequest.where(status: 'installation', installation_status: 'waiting_for_stock').order(:updated_at,
                                                                                                 :id).each do |request|
      note = new(request, now: now).call
      next unless request.installation_status == 'scheduled'

      request.updates.create!(status: request.status, progress: request.progress,
                              note: "The parts are in stock now. #{note}")
      planned += 1
    end
    planned
  end

  def initialize(request, now: Time.current)
    @request = request
    @now = now
    @setting = InstallationSetting.current
    @job_counts = {}
  end

  # Returns a sentence for the request's timeline
  def call
    @request.stock_reservations.destroy_all
    needs = @request.required_parts
    short = needs.select { |item, qty| item.available_quantity < qty }

    if short.any?
      @request.update!(installation_status: 'waiting_for_stock', installation_scheduled_on: nil)
      list = short.map do |item, qty|
        "#{item.name} (need #{format('%g', qty)}, free #{format('%g', [item.available_quantity, 0].max)})"
      end
      return "Waiting for parts that are not in stock: #{list.to_sentence}. The installation is scheduled automatically as soon as they arrive."
    end

    needs.each { |item, qty| StockReservation.create!(service_request: @request, catalog_item: item, quantity: qty) }
    date, installer = earliest_slot
    attrs = { installation_status: 'scheduled', installation_scheduled_on: date, assigned_to_admin: false }
    attrs[:team_member] = installer if installer
    @request.update!(attrs)

    who = installer ? "with #{installer.name} (#{installer.department_label})" : '– no installer is available, please assign one'
    parts = needs.any? ? ' The parts are reserved.' : ''
    "Installation scheduled for #{day_label(date)} #{who}.#{parts}"
  end

  private

  # first working day that has an installer with room for another job
  def earliest_slot
    start = @now.hour < @setting.cutoff_hour ? @now.to_date : @now.to_date + 1
    installers = TeamMember.where(department: 'installation', active: true).order(:id).to_a
    (0..30).each do |offset|
      date = start + offset
      next if @setting.sunday_off && date.sunday?
      return [date, nil] if installers.empty?

      free = installers.select { |m| jobs_on(m, date) < @setting.jobs_per_installer_per_day }
      return [date, free.min_by { |m| [jobs_on(m, date), m.id] }] if free.any?
    end
    [start + 31, nil]
  end

  def jobs_on(member, date)
    @job_counts[[member.id,
                 date]] ||= ServiceRequest.where(status: 'installation', team_member_id: member.id,
                                                 installation_scheduled_on: date)
                                          .where.not(id: @request.id).count
  end

  def day_label(date)
    today = @now.to_date
    name = date.strftime('%a %d %b')
    return "today (#{name})" if date == today
    return "tomorrow (#{name})" if date == today + 1

    name
  end
end
