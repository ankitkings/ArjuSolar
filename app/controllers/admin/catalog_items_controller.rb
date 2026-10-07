module Admin
  # The parts price list: every part has its own price
  class CatalogItemsController < BaseController
    before_action :set_item, only: %i[edit update destroy]

    def index
      @category = params[:category].presence_in(CatalogItem::CATEGORIES.keys)
      scope = CatalogItem.order(:category, :name)
      scope = scope.where(category: @category) if @category
      @items = scope.group_by(&:category)
      @counts = CatalogItem.group(:category).count
    end

    def new
      @item = CatalogItem.new(category: params[:category].presence_in(CatalogItem::CATEGORIES.keys) || "panel")
    end

    def create
      @item = CatalogItem.new(item_params)
      @item.save ? redirect_to(admin_catalog_items_path, notice: "Part added") : render(:new, status: :unprocessable_entity)
    end

    def edit; end

    def update
      @item.update(item_params) ? redirect_to(admin_catalog_items_path, notice: "Part updated") : render(:edit, status: :unprocessable_entity)
    end

    def destroy
      @item.destroy
      redirect_to admin_catalog_items_path, notice: "Part removed. Quotes already made keep their prices."
    end

    private

    def set_item
      @item = CatalogItem.find(params[:id])
    end

    def item_params
      params.require(:catalog_item).permit(:category, :name, :unit, :unit_price, :capacity_kw, :active)
    end
  end
end
