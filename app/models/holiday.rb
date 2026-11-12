# A day off for the whole team: national holiday, festival, company holiday ... (Admin > Holidays).
# It is paid, it is not counted as a working day, nobody needs to mark attendance and no installation is booked.
class Holiday < ApplicationRecord
  KINDS = { "national" => "National holiday", "festival" => "Festival", "company" => "Company holiday", "other" => "Other" }.freeze
  NATIONAL_DAYS = [[1, 26, "Republic Day"], [8, 15, "Independence Day"], [10, 2, "Gandhi Jayanti"]].freeze   # the same date every year

  before_validation do
    self.name = name.to_s.strip
    self.note = note.to_s.strip.presence
  end

  validates :date, presence: true, uniqueness: { message: "already has a holiday" }
  validates :name, presence: true, length: { maximum: 80 }
  validates :kind, inclusion: { in: KINDS.keys }
  validates :note, length: { maximum: 200 }, allow_nil: true

  def self.on(date) = find_by(date: date)
  def self.on?(date) = exists?(date: date)
  def self.upcoming(count = 6) = where("date >= ?", Date.current).order(:date).limit(count)

  # the three national holidays of one year; the ones already added are left alone. Returns how many were added.
  def self.add_national_days(year)
    NATIONAL_DAYS.count do |month, day, name|
      create(date: Date.new(year, month, day), name: name, kind: "national").persisted?
    end
  end

  def kind_label = KINDS[kind]
end
