# frozen_string_literal: true

module Admin
  # Admin > Margins: the actual price we pay and our margin for every part.
  # The price the client pays (used in quotes and the staff price list) = actual price + margin.
  class MarginsController < BaseController
    def show
      @items = CatalogItem.order(:category, :name).to_a
    end

    def update
      saved = 0
      problems = []
      params[:parts]&.each_pair do |id, row|
        item = CatalogItem.find_by(id: id)
        next unless item

        attrs = {}
        attrs[:cost_price] = row[:cost_price].to_s.to_d if row[:cost_price].present?
        attrs[:margin] = row[:margin].to_s.to_d if row[:margin].present?
        next if attrs.empty? || attrs.all? { |key, value| item[key] == value }

        if item.update(attrs)
          saved += 1
        else
          problems << "#{item.name}: #{item.errors.full_messages.to_sentence}"
        end
      end
      if problems.any?
        redirect_to admin_margins_path, alert: problems.to_sentence
      else
        redirect_to admin_margins_path,
                    notice: saved.zero? ? 'Nothing changed.' : "Saved #{saved} #{'part'.pluralize(saved)}."
      end
    end
  end
end
