# The salary of one employee for one month, as paid. It keeps a copy of the attendance numbers of that
# month, so the record stays the same even if attendance is changed later.
class SalaryPayment < ApplicationRecord
  MODES = { "cash" => "Cash", "bank_transfer" => "Bank transfer", "upi" => "UPI", "cheque" => "Cheque" }.freeze

  belongs_to :team_member, optional: true

  before_validation :work_out_net

  validates :member_name, :month, :paid_on, presence: true
  validates :mode, inclusion: { in: MODES.keys }
  validates :monthly_salary, :earned, :bonus, :deduction, :net_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :month, uniqueness: { scope: :team_member_id, message: "is already paid for this employee" }, if: -> { team_member_id.present? }
  validate :deduction_is_not_more_than_the_pay
  validate :dates_make_sense

  # a new, not yet saved payment, filled from the month's attendance summary (Payroll::Summary)
  def self.for_summary(summary, month:, admin:)
    member = summary.member
    new(team_member_id: member.id, member_name: member.name, department: member.department_label, month: month.beginning_of_month,
        monthly_salary: summary.salary, working_days: summary.working_days, present_days: summary.present, half_days: summary.half_days,
        paid_leave_days: summary.paid_leave, unpaid_leave_days: summary.unpaid_leave, absent_days: summary.absent,
        payable_days: summary.payable, earned: summary.earned, paid_by: admin&.email, paid_on: Date.current)
  end

  def month_label = month.strftime("%B %Y")
  def mode_label = MODES[mode]

  private

  def work_out_net
    self.net_amount = earned.to_d + bonus.to_d - deduction.to_d
  end

  def deduction_is_not_more_than_the_pay
    errors.add(:deduction, "cannot be more than the salary plus the bonus") if deduction.to_d > earned.to_d + bonus.to_d
  end

  def dates_make_sense
    errors.add(:paid_on, "cannot be in the future") if paid_on && paid_on > Date.current
    errors.add(:month, "cannot be in the future") if month && month > Date.current.beginning_of_month
  end
end
