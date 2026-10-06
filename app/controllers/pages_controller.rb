class PagesController < ApplicationController
  before_action { Visit.log(request) if request.get? }

  def home
    @packages = SolarPackage.available.with_attached_image.limit(3)
    @projects = Installation.on_website.with_attached_photos.includes(:solar_package).order(installed_on: :desc).limit(3)
  end

  def about; end
  def services; end

  def systems
    @packages = SolarPackage.available.with_attached_image
  end

  # Finished installations with the installer's site photos
  def projects
    @projects = Installation.on_website.with_attached_photos.includes(:solar_package).order(installed_on: :desc)
  end

  def team
    @groups = TeamMember.public_listed.group_by(&:department)
  end

  def contact
    @service_request = ServiceRequest.new(message: "I am interested in solar installation. Please contact me.")
  end
end
