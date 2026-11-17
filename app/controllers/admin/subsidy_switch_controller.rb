module Admin
  # Admin > Subsidy switch: the one switch that turns the subsidy on or off in the whole project
  class SubsidySwitchController < BaseController
    def show
      @held_for_discom = ServiceRequest.where(installation_status: "waiting_for_approval").count
      @held_for_meter = ServiceRequest.where(installation_status: "waiting_for_net_meter").count
      @open_applications = SubsidyApplication.in_group("in_progress").count
    end

    def update
      if params[:state] == "off"
        released = SubsidySwitch.turn_off!(admin: current_admin)
        message = "The subsidy is switched OFF. It is left out of quotations, prices, the website and the process."
        message += " #{released} #{'job'.pluralize(released)} that waited for DISCOM or the net meter #{released == 1 ? 'was' : 'were'} let go on." if released.positive?
        redirect_to admin_subsidy_switch_path, notice: message
      else
        SubsidySwitch.turn_on!
        redirect_to admin_subsidy_switch_path, notice: "The subsidy is switched ON. New quotations can carry it again."
      end
    end
  end
end
