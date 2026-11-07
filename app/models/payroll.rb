# frozen_string_literal: true

# Attendance, leave and salary of one month.
# Salary = monthly salary / working days of the month x payable days.
# Payable day: present = 1, half day = 0.5, paid leave = 1. Unpaid leave and absent = 0. Weekly offs are paid.
class Payroll
  Summary = Struct.new(:member, :salary, :working_days, :present, :half_days, :paid_leave, :unpaid_leave, :absent,
                       :remaining, :payable, :daily_rate, :earned, :projected, keyword_init: true) do
    def complete? = remaining.zero?
  end

  attr_reader :first_day, :last_day

  def initialize(month)
    @first_day = month.beginning_of_month
    @last_day = month.end_of_month
    @setting = AttendanceSetting.current
  end

  def off_day?(date) = @setting.sunday_off && date.sunday?
  def working_dates = (@first_day..@last_day).reject { |date| off_day?(date) }
  def summaries(members) = members.map { |member| summary(member) }

  def summary(member)
    working = working_dates
    result = Summary.new(member: member, salary: member.monthly_salary, working_days: working.size,
                         present: 0, half_days: 0, paid_leave: 0, unpaid_leave: 0, absent: 0, remaining: 0, payable: 0.0)
    working.each do |date|
      kind = day_status(member, date).first
      case kind
      when :present then result.present += 1
                         result.payable += 1
      when :half_day then result.half_days += 1
                          result.payable += 0.5
      when :paid_leave then result.paid_leave += 1
                            result.payable += 1
      when :unpaid_leave then result.unpaid_leave += 1
      when :absent       then result.absent += 1
      when :future, :today then result.remaining += 1
      end
    end
    if result.salary && result.working_days.positive?
      result.daily_rate = result.salary / result.working_days
      result.earned = (result.daily_rate * result.payable).round(2)
      result.projected = (result.daily_rate * (result.payable + result.remaining)).round(2)
    end
    result
  end

  # every calendar day of the month: [date, kind, label, counted days, attendance record]
  def days(member)
    (@first_day..@last_day).map { |date| [date, *day_status(member, date)] }
  end

  private

  def attendances
    @attendances ||= Attendance.where(date: @first_day..@last_day).group_by(&:team_member_id).transform_values do |list|
      list.index_by(&:date)
    end
  end

  def leaves
    @leaves ||= LeaveRequest.approved.where('from_date <= ? AND to_date >= ?', @last_day,
                                            @first_day).group_by(&:team_member_id)
  end

  def day_status(member, date)
    return [:off, 'Weekly off', nil, nil] if off_day?(date)

    leave = (leaves[member.id] || []).find { |l| l.covers?(date) }
    return [leave.paid? ? :paid_leave : :unpaid_leave, leave.kind_label, (leave.paid? ? 1.0 : 0.0), nil] if leave
    return [:future, '', nil, nil] if date > Date.current

    record = attendances.dig(member.id, date)
    return [record.status.to_sym, record.status_label, record.counted_days, record] if record

    date == Date.current ? [:today, 'Not marked yet', nil, nil] : [:absent, 'Absent (not marked)', 0.0, nil]
  end
end
