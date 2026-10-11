module Admin
  # The catalog of systems the installation team chooses from
  class SolarPackagesController < BaseController
    before_action :set_package, only: %i[edit update destroy]

    def index
      @packages = SolarPackage.with_attached_image.order(:capacity_kw, :name)
      @usage = Installation.group(:solar_package_id).count
    end

    def new
      @package = SolarPackage.new(active: true)
    end

    def create
      @package = SolarPackage.new(package_params)
      save_with_parts(@package) ? redirect_to(admin_solar_packages_path, notice: "System added") : render(:new, status: :unprocessable_entity)
    end

    def edit; end

    def update
      @package.assign_attributes(package_params)
      if save_with_parts(@package)
        @package.image.purge if params[:remove_image] == "1" && package_params[:image].blank?
        redirect_to admin_solar_packages_path, notice: "System updated"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @package.destroy
      redirect_to admin_solar_packages_path, notice: "System removed. Installations already done keep their saved data."
    end

    private

    def set_package
      @package = SolarPackage.find(params[:id])
    end

    def package_params
      params.require(:solar_package).permit(:name, :capacity_kw, :price, :panel_count, :panel_brand, :inverter_model, :active, :subsidy_eligible, :image)
    end

    # The parts chosen on the form: [[catalog_item, quantity], ...]. nil when the form had no parts section.
    def parts_rows
      return nil unless params[:parts_section].present?
      Array(params[:items]).filter_map do |row|
        item = CatalogItem.find_by(id: row[:catalog_item_id])
        qty = row[:quantity].to_s.to_d
        [item, qty] if item && qty.positive?
      end
    end

    # Saves the system; with parts, its price, panel count, brand and inverter are calculated from them
    def save_with_parts(package)
      rows = parts_rows
      package.assign_attributes(SolarPackage.attributes_from_parts(rows)) if rows.present?
      SolarPackage.transaction do
        package.save!
        package.replace_parts!(rows) unless rows.nil?
      end
      true
    rescue ActiveRecord::RecordInvalid
      false
    end
  end
end
