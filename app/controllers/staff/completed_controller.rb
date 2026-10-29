module Staff
  # Staff > Completed work: everything I finished, month by month
  class CompletedController < BaseController
    def index
      @work = CompletedWork.new(current_staff)
      @month = parse_month(params[:month])
      @items = @work.in_month(@month)
    end

    private

    def parse_month(value)
      Date.strptime(value.to_s, "%Y-%m")
    rescue ArgumentError
      Date.current.beginning_of_month
    end
  end
end
