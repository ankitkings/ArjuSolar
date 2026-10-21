module Admin
  # Admin > Stock: parts in hand, what has to be ordered, and the rules for planning installations
  class StockController < BaseController
    def show
      @tab = params[:tab].presence_in(%w[stock order history]) || "stock"
      case @tab
      when "stock"
        @items = CatalogItem.stocked.order(:category, :name).to_a
        @reserved = StockReservation.group(:catalog_item_id).sum(:quantity)
        @setting = InstallationSetting.current
      when "order"
        @include_quotes = params[:include_quotes] == "1"
        @report = RequiredParts.new(include_quotes: @include_quotes)
        @orders = StockOrder.open_orders.includes(:catalog_item).order(:ordered_on, :id).to_a
      when "history"
        @movements = StockMovement.includes(:catalog_item, :service_request).order(created_at: :desc, id: :desc).limit(150)
      end
    end

    # Parts arrived
    def receive
      item = CatalogItem.stocked.find(params[:item_id])
      qty = params[:quantity].to_s.to_d
      return redirect_to(admin_stock_path(tab: params[:tab].presence), alert: "Enter how many were received.") unless qty.positive?

      item.add_stock!(qty, kind: "received", note: params[:note].presence || "Stock received")
      planned = InstallationScheduler.process_waiting!
      msg = "Added #{format('%g', qty)} #{item.unit} of #{item.name}."
      msg += " #{planned} waiting installation#{'s' if planned != 1} could be scheduled now." if planned.positive?
      redirect_to admin_stock_path(tab: params[:tab].presence), notice: msg
    end

    # Record an order. Any part and any quantity: the suggested quantities can be changed, parts can be
    # left out, and parts that were not suggested at all can be ordered too.
    def order
      entries = []
      if params[:orders].present?
        params[:orders].each_pair { |item_id, row| entries << [item_id, row[:quantity]] if row[:place] == "1" }
      else
        entries << [params[:item_id], params[:quantity]]
      end
      placed = entries.filter_map do |item_id, quantity|
        item = CatalogItem.stocked.find_by(id: item_id)
        qty = quantity.to_s.to_d
        next unless item && qty.positive?
        StockOrder.create!(catalog_item: item, quantity: qty, ordered_on: Date.current,
                           supplier: params[:supplier].presence, note: params[:note].presence)
      end
      if placed.empty?
        redirect_to admin_stock_path(tab: "order"), alert: "Choose a part and a quantity to order."
      else
        redirect_to admin_stock_path(tab: "order"), notice: "Order recorded: #{placed.map { |o| "#{format('%g', o.quantity)} × #{o.catalog_item.name}" }.to_sentence}."
      end
    end

    # The ordered parts arrived (the quantity that really came can be different)
    def receive_order
      order = StockOrder.open_orders.find(params[:id])
      order.receive!(params[:received_quantity])
      planned = InstallationScheduler.process_waiting!
      msg = "#{order.catalog_item.name}: #{format('%g', order.quantity_received)} added to the stock."
      msg += " #{planned} waiting installation#{'s' if planned != 1} could be scheduled now." if planned.positive?
      redirect_to admin_stock_path(tab: "order"), notice: msg
    end

    def cancel_order
      StockOrder.open_orders.find(params[:id]).update!(status: "cancelled")
      redirect_to admin_stock_path(tab: "order"), notice: "Order cancelled."
    end

    # After counting the shelf: set the real quantity
    def adjust
      item = CatalogItem.stocked.find(params[:item_id])
      return redirect_to(admin_stock_path, alert: "Enter the counted quantity.") if params[:counted].blank?

      counted = params[:counted].to_s.to_d
      return redirect_to(admin_stock_path, alert: "The counted quantity cannot be negative.") if counted.negative?

      diff = counted - item.stock_quantity
      return redirect_to(admin_stock_path, notice: "No change – the count matches.") if diff.zero?

      item.add_stock!(diff, kind: "adjustment", note: "Count corrected from #{format('%g', item.stock_quantity)} to #{format('%g', counted)}")
      InstallationScheduler.process_waiting! if diff.positive?
      redirect_to admin_stock_path, notice: "#{item.name}: count set to #{format('%g', counted)} #{item.unit}."
    end

    # Order again below this quantity
    def min_level
      item = CatalogItem.stocked.find(params[:item_id])
      item.update_columns(min_stock: [params[:min_stock].to_s.to_d, 0].max)
      redirect_to admin_stock_path, notice: "Minimum level saved for #{item.name}."
    end

    def rules
      setting = InstallationSetting.current
      if setting.update(params.require(:installation_setting).permit(:cutoff_hour, :work_end_hour, :jobs_per_installer_per_day, :sunday_off))
        redirect_to admin_stock_path, notice: "Scheduling rules saved"
      else
        redirect_to admin_stock_path, alert: setting.errors.full_messages.to_sentence
      end
    end
  end
end
