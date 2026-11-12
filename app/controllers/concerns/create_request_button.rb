# Puts the "Create request" button at the top of a site visitor's dashboard (Staff > My tasks)
module CreateRequestButton
  extend ActiveSupport::Concern

  included do
    after_action :add_create_request_button, only: :index
  end

  private

  def add_create_request_button
    return unless current_staff&.department == "site_visitor"
    return unless response.successful? && response.media_type == "text/html"
    body = response.body.to_s
    html = view_context.render(partial: "staff/requests/create_button")
    heading = body.index("</h1>")
    position = heading ? heading + "</h1>".length : (body.index(/<main[^>]*>/) && body.index(">", body.index(/<main[^>]*>/)) + 1)
    return unless position
    response.body = body.dup.insert(position, html)
  end
end
