# The rules of the system type on the models that already exist.
module SubsidyOffForOffGridPackage
  def subsidy_amount = system_type == "off_grid" ? 0 : super
  def effective_cost = system_type == "off_grid" ? price : super
end

Rails.application.config.to_prepare do
  SolarPackage.prepend(SubsidyOffForOffGridPackage) unless SolarPackage.include?(SubsidyOffForOffGridPackage)

  SolarPackage.class_eval do
    validates :system_type, inclusion: { in: SystemType::TYPES.keys }
    validate :on_grid_has_no_battery

    def on_grid_has_no_battery
      return unless system_type == "on_grid" && persisted?
      if package_items.joins(:catalog_item).where(catalog_items: { category: "battery" }).exists?
        errors.add(:system_type, "On-grid systems have no battery. Take the battery out of the parts first, or choose Hybrid or Off-grid.")
      end
    end
  end

  PackageItem.class_eval do
    validate :battery_fits_the_system_type

    def battery_fits_the_system_type
      return unless solar_package && catalog_item
      if SystemType.battery?(catalog_item) && !SystemType.battery_allowed?(solar_package.system_type)
        errors.add(:base, "An on-grid system has no battery. Change the system to Hybrid or Off-grid first.")
      end
    end
  end
end
