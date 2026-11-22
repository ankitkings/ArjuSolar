# The three kinds of solar system, and what each one means for the price:
#   on-grid  : connected to the electricity grid, no battery   -> the battery price is NOT added, the subsidy can apply
#   off-grid : runs on batteries, no grid connection           -> the battery is part of the price, NO subsidy
#   hybrid   : connected to the grid and has a battery         -> battery and subsidy are both possible
module SystemType
  TYPES = { "on_grid" => "On-grid", "off_grid" => "Off-grid", "hybrid" => "Hybrid" }.freeze
  INFO = {
    "on_grid" => "Connected to the electricity grid, without a battery. The subsidy can apply.",
    "off_grid" => "Runs on batteries, without the grid. No subsidy.",
    "hybrid" => "Connected to the grid and has a battery. The subsidy can apply."
  }.freeze

  def self.valid?(type) = TYPES.key?(type.to_s)
  def self.battery_allowed?(type) = type.to_s != "on_grid"
  def self.subsidy_allowed?(type) = type.to_s != "off_grid"
  def self.battery?(catalog_item) = catalog_item.respond_to?(:category) && catalog_item.category == "battery"

  # a custom quotation has no type chosen: a battery makes it hybrid (with subsidy) or off-grid (without)
  def self.infer(items, subsidy)
    return "on_grid" unless items.any? { |item, _| battery?(item) }
    subsidy ? "hybrid" : "off_grid"
  end
end
