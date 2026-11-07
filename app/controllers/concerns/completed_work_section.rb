# Shows "My completed work" at the bottom of each team member's dashboard (Staff > My tasks)
module CompletedWorkSection
  extend ActiveSupport::Concern

  included do
    after_action :add_completed_work_section, only: :index
  end

  private

  def add_completed_work_section
    return unless response.successful? && response.media_type == "text/html"
    body = response.body.to_s
    position = body.rindex("</main>")
    return unless position
    html = view_context.render(partial: "staff/completed_work/section", locals: { work: CompletedWork.new(current_staff) })
    response.body = body.dup.insert(position, html)
  end
end
