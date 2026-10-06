module Admin
  class TeamMembersController < BaseController
    DONE = %w[completed cancelled].freeze

    before_action :set_member, only: %i[show edit update destroy]

    def index
      @members = TeamMember.order(:department, :name)
      @open_counts = ServiceRequest.where(status: RequestWorkflow::ACTIVE_STATUSES).where.not(team_member_id: nil).group(:team_member_id).count
      @active_counts = TeamMember.active_task_counts
      @visit_counts = MaintenanceVisit.where(status: "assigned").group(:team_member_id).count
      @payment_counts = Payment.where(status: %w[pending partial]).group(:team_member_id).count
      # money still to be collected, per cashier
      @to_collect = Payment.where(status: %w[pending partial]).where.not(team_member_id: nil).includes(:receipts).group_by(&:team_member_id)
      @done_counts = Hash.new(0)
      [ServiceRequest.where(status: "completed"), MaintenanceVisit.where(status: "done"), Payment.where(status: "received")].each do |rel|
        rel.group(:team_member_id).count.each { |id, n| @done_counts[id] += n }
      end
    end

    # One team member's tasks + recent activity
    def show
      scope = @member.service_requests.order(updated_at: :desc)
      @counts = {
        "open"      => scope.where.not(status: DONE).count,
        "completed" => scope.where(status: "completed").count,
        "all"       => scope.count
      }
      @filter = params[:filter].presence_in(@counts.keys) || "open"
      @tasks = case @filter
               when "open"      then scope.where.not(status: DONE)
               when "completed" then scope.where(status: "completed")
               else scope
               end
      @activity = @member.request_updates.includes(:service_request).order(created_at: :desc).limit(10)
      @visits = @member.maintenance_visits.includes(:service_request).order(:due_on)
      pay_scope = @member.payments.includes(:receipts, service_request: { installation: :solar_package }).order(:created_at)
      @to_collect = pay_scope.where(status: %w[pending partial]).to_a
      @collected = pay_scope.where(status: "received").to_a
      @to_collect_total = @to_collect.sum { |p| p.balance || 0 }
    end

    def new
      @member = TeamMember.new
    end

    def create
      @member = TeamMember.new(member_params)
      @member.save ? redirect_to(admin_team_members_path, notice: "Member added") : render(:new, status: :unprocessable_entity)
    end

    def edit; end

    def update
      @member.update(member_params) ? redirect_to(admin_team_members_path, notice: "Member updated") : render(:edit, status: :unprocessable_entity)
    end

    def destroy
      @member.destroy
      redirect_to admin_team_members_path, notice: "Member removed"
    end

    private

    def set_member = @member = TeamMember.find(params[:id])
    def member_params = params.require(:team_member).permit(:name, :department, :phone, :bio, :show_on_website, :active, :email, :password)
  end
end
