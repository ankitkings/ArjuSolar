module Admin
  class VisitsController < BaseController
    def index
      @visits = Visit.order(visited_at: :desc).limit(500)
      @top_pages = Visit.group(:path).order("count_all DESC").limit(5).count
      @browsers = Visit.group(:browser).count
      @devices = Visit.group(:device).count
    end
  end
end
