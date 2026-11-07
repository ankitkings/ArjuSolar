module Admin
  # Admin > Salary records: pay the salary worked out in Payroll and keep the record of every month
  class SalaryPaymentsController < BaseController
    CSV_HEADER = ["Month", "Employee", "Department", "Monthly salary", "Working days", "Present", "Half days", "Paid leave", "Unpaid leave",
                  "Absent", "Payable days", "Salary earned", "Bonus", "Deduction", "Net paid", "Paid by (mode)", "Reference", "Paid on", "Recorded by"].freeze

    # the register: every month paid, filtered by month and/or employee, with a CSV download
    def index
      @month = parse_month(params[:month])
      @member_id = params[:member_id].presence
      scope = SalaryPayment.order(month: :desc, member_name: :asc)
      scope = scope.where(month: @month) if @month
      scope = scope.where(team_member_id: @member_id) if @member_id
      @payments = scope.to_a
      @months = SalaryPayment.group(:month).order(month: :desc).pluck(:month, Arel.sql("COUNT(*)"), Arel.sql("SUM(net_amount)"))
      @members = TeamMember.order(:name).to_a
      respond_to do |format|
        format.html
        format.csv do
          send_data csv_for(@payments), type: "text/csv; charset=utf-8",
                                        filename: "salary-records-#{@month ? @month.strftime('%Y-%m') : 'all'}.csv"
        end
      end
    end

    # the payslip (printable)
    def show
      @payment = SalaryPayment.find(params[:id])
    end

    def new
      load_pay_form
      return if performed?
      @payment = SalaryPayment.for_summary(@summary, month: @month, admin: current_admin)
    end

    def create
      load_pay_form
      return if performed?
      @payment = SalaryPayment.for_summary(@summary, month: @month, admin: current_admin)   # the numbers come from the attendance, not from the form
      @payment.assign_attributes(params.require(:salary_payment).permit(:bonus, :bonus_note, :deduction, :deduction_note, :mode, :reference, :paid_on, :note))
      if @payment.save
        redirect_to admin_salary_payment_path(@payment), notice: "Salary of #{@member.name} for #{@payment.month_label} is paid: #{helpers.inr(@payment.net_amount)}. The record is saved."
      else
        render :new, status: :unprocessable_entity
      end
    end

    # undo: the month becomes unpaid again
    def destroy
      payment = SalaryPayment.find(params[:id])
      payment.destroy
      redirect_to admin_payroll_path(month: payment.month.strftime("%Y-%m")), notice: "The payment record of #{payment.member_name} for #{payment.month_label} was removed. The salary is unpaid again."
    end

    private

    def load_pay_form
      @member = TeamMember.find(params[:member_id])
      @month = parse_month(params[:month]) || Date.current.beginning_of_month
      back = admin_payroll_path(month: @month.strftime("%Y-%m"))
      if (existing = SalaryPayment.find_by(team_member_id: @member.id, month: @month))
        return redirect_to(admin_salary_payment_path(existing), notice: "This salary is already paid.")
      end
      return redirect_to(back, alert: "The salary of a future month cannot be paid yet.") if @month > Date.current.beginning_of_month
      @summary = Payroll.new(@month).summary(@member)
      redirect_to(back, alert: "Set the monthly salary of #{@member.name} first.") unless @summary.earned
    end

    def parse_month(value)
      Date.strptime(value.to_s, "%Y-%m")
    rescue ArgumentError
      nil
    end

    def csv_for(payments)
      rows = payments.map do |p|
        [p.month_label, p.member_name, p.department, p.monthly_salary, p.working_days, p.present_days, p.half_days, p.paid_leave_days,
         p.unpaid_leave_days, p.absent_days, p.payable_days, p.earned, p.bonus, p.deduction, p.net_amount, p.mode_label, p.reference,
         p.paid_on.strftime("%d-%m-%Y"), p.paid_by]
      end
      "\uFEFF" + ([CSV_HEADER] + rows).map { |row| row.map { |value| %("#{value.to_s.gsub('"', '""')}") }.join(",") }.join("\r\n")
    end
  end
end
