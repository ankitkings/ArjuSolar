module Admin
  # Admin > Build a system: make (or change) a ready-made on-grid, off-grid or hybrid system from the parts in stock.
  # Price, number of panels, panel brand and inverter follow the parts.
  class PackageBuilderController < BaseController
    def new
      @package = SolarPackage.new(system_type: SystemType.valid?(params[:type]) ? params[:type] : "on_grid", active: true, subsidy_eligible: true)
      @quantities = {}
      load_parts
    end

    def edit
      @package = SolarPackage.find(params[:id])
      @quantities = @package.package_items.to_h { |item| [item.catalog_item_id, item.quantity] }
      load_parts
    end

    def create
      @package = SolarPackage.new
      save_package(:new)
    end

    def update
      @package = SolarPackage.find(params[:id])
      save_package(:edit)
    end

    private

    def load_parts
      @parts = CatalogItem.available.to_a.sort_by(&:name).group_by(&:category)
    end

    def save_package(page)
      attrs = params.require(:package).permit(:name, :capacity_kw, :system_type, :active, :subsidy_eligible).to_h
      @quantities = (params[:parts] || {}).to_unsafe_h.transform_keys(&:to_i).transform_values { |value| value.to_s.to_d }.select { |_, qty| qty.positive? }
      items = CatalogItem.where(id: @quantities.keys).index_by(&:id)
      rows = @quantities.filter_map { |id, qty| [items[id], qty] if items[id] }
      type = attrs["system_type"]

      @errors = []
      @errors << "Choose the type of system." unless SystemType.valid?(type)
      @errors << "Add at least one solar panel." unless rows.any? { |item, _| item.category == "panel" }
      @errors << "Add an inverter." unless rows.any? { |item, _| item.category == "inverter" }
      has_battery = rows.any? { |item, _| SystemType.battery?(item) }
      @errors << "An on-grid system has no battery. Take the battery out, or choose Hybrid or Off-grid." if type == "on_grid" && has_battery
      @errors << "A #{SystemType::TYPES[type]} system needs a battery. Add one from the stock." if %w[off_grid hybrid].include?(type) && !has_battery

      if @errors.empty?
        begin
          attrs["subsidy_eligible"] = false if type == "off_grid"   # no subsidy off-grid
          SolarPackage.transaction do
            @package.assign_attributes(attrs.merge(SolarPackage.attributes_from_parts(rows)))
            @package.package_items.destroy_all if @package.persisted?
            @package.save!
            @package.replace_parts!(rows)
          end
          short = rows.select { |item, qty| item.tracks_stock? && item.available_quantity < qty }
          notice = "#{@package.label} saved: #{inr_text(@package.price)}, #{SystemType::TYPES[type]}."
          notice += " Stock is short for: #{short.map { |item, qty| "#{item.name} (need #{format('%g', qty)}, free #{format('%g', [item.available_quantity, 0].max)})" }.to_sentence}." if short.any?
          return redirect_to(admin_system_types_path, notice: notice)
        rescue ActiveRecord::RecordInvalid => e
          @errors = e.record.errors.full_messages
        end
      end

      @package.assign_attributes(attrs.slice("name", "capacity_kw", "system_type", "active", "subsidy_eligible"))   # the form shows what was typed
      load_parts
      render page, status: :unprocessable_entity
    end

    def inr_text(amount) = helpers.inr(amount)
  end
end
