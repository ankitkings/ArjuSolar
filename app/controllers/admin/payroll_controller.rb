# frozen_string_literal: true

module Admin
  # Admin > Payroll: salary of every employee, worked out from attendance and approved leave
  class PayrollController < BaseController
    def index
      @month = parse_month(params[:month])
      @payroll = Payroll.new(@month)
      @members = TeamMember.where(active: true).order(:department, :name).to_a
      @summaries = @payroll.summaries(@members)
      @setting = AttendanceSetting.current
    end

    # one employee, day by day
    def show
      @member = TeamMember.find(params[:member_id])
      @month = parse_month(params[:month])
      @payroll = Payroll.new(@month)
      @summary = @payroll.summary(@member)
      @days = @payroll.days(@member)
    end

    def salary
      member = TeamMember.find(params[:member_id])
      amount = params[:monthly_salary].to_s.strip
      if amount.blank?
        member.update_columns(monthly_salary: nil)
      elsif amount.to_d.negative?
        return redirect_to(admin_payroll_path(month: params[:month].presence), alert: 'The salary cannot be negative.')
      else
        member.update_columns(monthly_salary: amount.to_d)
      end
      redirect_to admin_payroll_path(month: params[:month].presence), notice: "Salary of #{member.name} saved."
    end

    def settings
      setting = AttendanceSetting.current
      if setting.update(params.require(:attendance_setting).permit(:half_day_hours, :sunday_off))
        redirect_to admin_payroll_path(month: params[:month].presence), notice: 'Rules saved.'
      else
        redirect_to admin_payroll_path(month: params[:month].presence), alert: setting.errors.full_messages.to_sentence
      end
    end

    private

    def parse_month(value)
      Date.strptime(value.to_s, '%Y-%m')
    rescue ArgumentError
      Date.current.beginning_of_month
    end
  end
end
