module Admin
  # Admin > My tasks: everything that is waiting for the admin, with an alert for new tasks
  class MyTasksController < BaseController
    def index
      @tasks = AdminTasks.for(current_admin)
      @list = @tasks.tasks            # worked out first, so the "new" marks are still there ...
      AdminTasks.mark_seen!(current_admin)   # ... and everything counts as seen from now on
    end

    # asked by every admin page every half minute: is there a new task?
    def alert
      tasks = AdminTasks.for(current_admin)
      newest = tasks.tasks.select(&:fresh).max_by(&:since)
      render json: { count: tasks.count, new_count: tasks.new_count,
                     newest: (newest && { at: newest.since.iso8601, title: newest.title, detail: newest.detail }) }
    end
  end
end
