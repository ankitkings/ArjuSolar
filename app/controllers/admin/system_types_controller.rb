module Admin
  # Admin > System types: is each ready-made system on-grid, off-grid or hybrid?
  class SystemTypesController < BaseController
    def show
      @packages = SolarPackage.order(:capacity_kw, :name).to_a
      @with_battery = PackageItem.joins(:catalog_item).where(catalog_items: { category: "battery" }).distinct.pluck(:solar_package_id)
    end

    def update
      problems = []
      changed = 0
      (params[:types] || {}).each_pair do |id, type|
        package = SolarPackage.find_by(id: id)
        next unless package && SystemType.valid?(type) && package.system_type != type
        package.system_type = type
        if package.save then changed += 1
        else problems << "#{package.name}: #{package.errors.full_messages.to_sentence}"
        end
      end
      if problems.any?
        redirect_to admin_system_types_path, alert: problems.to_sentence
      else
        redirect_to admin_system_types_path, notice: changed.zero? ? "Nothing changed." : "#{changed} #{'system'.pluralize(changed)} updated."
      end
    end
  end
end
