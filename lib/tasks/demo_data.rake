# frozen_string_literal: true

namespace :demo do
  desc 'Example actual prices for parts that have no margin yet (selling prices do not change)'
  task margins: :environment do
    count = 0
    CatalogItem.where(margin: 0).find_each do |item|
      cost = (item.unit_price * 0.88).round
      item.update!(cost_price: cost, margin: item.unit_price - cost)
      count += 1
    end
    puts "Example actual prices set on #{count} parts."
  end

  desc 'Example salaries, 3 weeks of attendance and a few leave requests for the team'
  task attendance: :environment do
    rng = Random.new(11)
    salaries = { 'contact_person' => 22_000, 'site_visitor' => 25_000, 'installation' => 28_000,
                 'daily_servicing' => 20_000, 'cashier' => 21_000 }
    members = TeamMember.where(active: true).order(:id).to_a
    members.each { |m| m.update_columns(monthly_salary: salaries[m.department]) if m.monthly_salary.nil? }
    sunday_off = AttendanceSetting.current.sunday_off

    leave_days = Hash.new { |hash, key| hash[key] = [] }
    plan = [[0, :approved, -5, -4, 'paid', 'Family function'], [1, :pending, 1, 2, 'paid', 'Visiting my native place'],
            [2, :cancelled, -2, -2, 'sick', 'Fever'], [3, :approved, -6, -6, 'unpaid', 'Personal work']]
    plan.each do |index, outcome, from, to, kind, reason|
      member = members[index] or next
      leave = LeaveRequest.new(team_member: member, kind: kind, from_date: Date.current + from,
                               to_date: Date.current + to, reason: reason)
      next unless leave.save

      leave.approve! if outcome == :approved
      leave.cancel!(by: 'admin', note: 'Not possible this week') if outcome == :cancelled
      leave_days[member.id] += (leave.from_date..leave.to_date).to_a if outcome == :approved
    end

    made = 0
    members.each do |member|
      ((Date.current - 21)..(Date.current - 1)).each do |date|
        next if sunday_off && date.sunday?
        next if leave_days[member.id].include?(date)
        next if Attendance.exists?(team_member_id: member.id, date: date)

        roll = rng.rand
        status = if roll < 0.85
                   'present'
                 else
                   (roll < 0.93 ? 'half_day' : 'absent')
                 end
        attrs = { team_member: member, date: date, status: status, marked_by: 'self' }
        unless status == 'absent'
          attrs[:check_in_at] = Time.zone.local(date.year, date.month, date.day, 9, rng.rand(0..40))
          attrs[:check_out_at] =
            Time.zone.local(date.year, date.month, date.day, status == 'half_day' ? 13 : 18, rng.rand(0..50))
        end
        Attendance.create!(attrs)
        made += 1
      end
      next if sunday_off && Date.current.sunday?
      next if leave_days[member.id].include?(Date.current) || Attendance.exists?(team_member_id: member.id,
                                                                                 date: Date.current)

      if rng.rand < 0.7
        Attendance.create!(team_member: member, date: Date.current, status: 'present', marked_by: 'self',
                           check_in_at: Time.current - 2.hours)
      end
    end
    puts "Salaries set, #{made} attendance days and #{LeaveRequest.count} leave requests created."
  end
end
