class PagesController < ApplicationController
  before_action { Visit.log(request) if request.get? }

  def home; end
  def about; end
  def services; end
  def projects; end

  def team
    @groups = TeamMember.public_listed.group_by(&:department)
  end

  def contact
    @service_request = ServiceRequest.new(message: "I am interested in solar installation. Please contact me.")
  end
end
