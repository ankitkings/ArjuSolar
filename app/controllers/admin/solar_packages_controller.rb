module Admin
  # The catalog of systems the installation team chooses from
  class SolarPackagesController < BaseController
    before_action :set_package, only: %i[edit update destroy]

    def index
      @packages = SolarPackage.order(:capacity_kw, :name)
      @usage = Installation.group(:solar_package_id).count
    end

    def new
      @package = SolarPackage.new(active: true)
    end

    def create
      @package = SolarPackage.new(package_params)
      @package.save ? redirect_to(admin_solar_packages_path, notice: "System added") : render(:new, status: :unprocessable_entity)
    end

    def edit; end

    def update
      @package.update(package_params) ? redirect_to(admin_solar_packages_path, notice: "System updated") : render(:edit, status: :unprocessable_entity)
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
      params.require(:solar_package).permit(:name, :capacity_kw, :price, :panel_count, :panel_brand, :inverter_model, :active)
    end
  end
end
