# Central subsidy for home rooftop solar (PM Surya Ghar: Muft Bijli Yojana).
# Rs 30,000 per kW for the first 2 kW, Rs 18,000 for the 3rd kW, nothing more above 3 kW => max Rs 78,000.
# The rates live in the database so the admin can change them if the scheme is revised.
class SubsidyScheme < ApplicationRecord
  validates :first_slab_kw, :first_rate, :cap_kw, :second_rate, numericality: { greater_than_or_equal_to: 0 }
  validate :cap_not_below_first_slab

  def self.current = first || create!

  def amount_for(kw)
    return 0 unless active
    kw = kw.to_f
    first  = [kw, first_slab_kw.to_f].min * first_rate.to_f
    second = [[kw, cap_kw.to_f].min - first_slab_kw.to_f, 0].max * second_rate.to_f
    (first + second).round
  end

  def maximum = amount_for(cap_kw)

  private

  def cap_not_below_first_slab
    errors.add(:cap_kw, "cannot be smaller than the first slab") if cap_kw && first_slab_kw && cap_kw < first_slab_kw
  end
end
