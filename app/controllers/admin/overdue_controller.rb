module Admin
  class OverdueController < BaseController
    def index
      @overdue = OverdueSteps.new
    end

    # the admin changes how many days a step may take
    def update_limits
      defaults = OverdueSteps.defaults
      problems = []
      params[:limits]&.each_pair do |key, value|
        next unless defaults.key?(key) && value.to_s.strip.present?
        limit = OverdueLimit.find_or_initialize_by(key: key)
        limit.days = value.to_s.to_i
        problems << "#{OverdueSteps.label_for(key)}: #{limit.errors.full_messages.to_sentence}" unless limit.save
      end
      if problems.any?
        redirect_to admin_overdue_path, alert: problems.to_sentence
      else
        redirect_to admin_overdue_path, notice: "The days were saved."
      end
    end

    def reset_limits
      OverdueLimit.delete_all
      redirect_to admin_overdue_path, notice: "All steps are back to the standard days."
    end
  end
end
