module Staff
  # Read-only price list for the team, to show the client what things cost
  class PartsController < BaseController
    def index
      @tab = params[:tab].presence_in(%w[parts systems]) || "parts"
      @parts = CatalogItem.available.group_by(&:category)
      @systems = SolarPackage.available.includes(package_items: :catalog_item)
    end
  end
end
