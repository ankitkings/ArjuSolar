# The "parts to order" list: what the open installations need, what is in stock, what is already
# on order, and what is still short.
class RequiredParts
  Row = Struct.new(:item, :needed, :in_stock, :reserved, :on_order, :short, :requests, keyword_init: true) do
    def free = in_stock - reserved
  end

  # include_quotes: also count quotes waiting for the client's answer and jobs waiting for the electricity company
  def initialize(include_quotes: false)
    @include_quotes = include_quotes
  end

  def rows = (@rows ||= build)
  def short_rows = rows.select { |r| r.short.positive? }

  # parts that are below their minimum level
  def low_stock_items
    @low ||= CatalogItem.stocked.select { |i| i.min_stock.positive? && i.stock_quantity < i.min_stock }
  end

  # [[item, suggested quantity, why], ...] - what is still missing after the parts already on order
  def order_lines
    @order_lines ||= begin
      lines = {}
      short_rows.each do |r|
        qty = r.short - r.on_order
        lines[r.item] = [qty, "needed for jobs"] if qty.positive?
      end
      low_stock_items.each do |item|
        refill = item.min_stock - item.stock_quantity - on_order_for(item)
        lines[item] = [refill, "below the minimum level"] if refill.positive? && (!lines[item] || lines[item][0] < refill)
      end
      lines.map { |item, (qty, why)| [item, qty, why] }.sort_by { |item, _, _| [item.category, item.name] }
    end
  end

  def count_to_order = order_lines.size
  def estimated_cost = order_lines.sum { |item, qty, _| item.unit_price * qty }

  def on_order_for(item) = on_order_map.fetch(item.id, 0).to_d

  private

  def on_order_map
    @on_order_map ||= StockOrder.open_orders.group(:catalog_item_id).sum(:quantity)
  end

  def build
    items = {}
    reserved = Hash.new(0)
    waiting = Hash.new(0)
    future = Hash.new(0)
    jobs = Hash.new { |hash, key| hash[key] = [] }

    StockReservation.includes(:catalog_item).each do |r|
      items[r.catalog_item_id] = r.catalog_item
      reserved[r.catalog_item_id] += r.quantity
      jobs[r.catalog_item_id] << r.service_request_id
    end

    ServiceRequest.where(status: "installation", installation_status: "waiting_for_stock").find_each do |request|
      request.required_parts.each do |item, qty|
        items[item.id] = item
        waiting[item.id] += qty
        jobs[item.id] << request.id
      end
    end

    if @include_quotes
      ServiceRequest.where(status: "installation", installation_status: "waiting_for_approval").find_each do |request|
        request.required_parts.each do |item, qty|
          items[item.id] = item
          future[item.id] += qty
          jobs[item.id] << request.id
        end
      end
      ServiceRequest.where(status: "quote_sent").find_each do |request|
        quote = request.latest_quote
        next unless quote && quote.status == "sent"
        quote.quote_items.includes(:catalog_item).each do |qi|
          item = qi.catalog_item
          next unless item&.tracks_stock?
          items[item.id] = item
          future[item.id] += qi.quantity
          jobs[item.id] << request.id
        end
      end
    end

    items.values.map do |item|
      free = item.stock_quantity - reserved[item.id]
      Row.new(item: item, needed: reserved[item.id] + waiting[item.id] + future[item.id], in_stock: item.stock_quantity,
              reserved: reserved[item.id], on_order: on_order_for(item), short: [waiting[item.id] + future[item.id] - free, 0].max,
              requests: jobs[item.id].uniq)
    end.sort_by { |r| [r.short.positive? ? 0 : 1, r.item.category, r.item.name] }
  end
end
