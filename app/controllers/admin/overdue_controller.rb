# frozen_string_literal: true

module Admin
  class OverdueController < BaseController
    def index
      @overdue = OverdueSteps.new
    end
  end
end
