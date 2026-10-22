# frozen_string_literal: true

# An employee asks for leave; the admin approves or cancels it.
class LeaveRequest < ApplicationRecord
  KINDS = { 'paid' => 'Paid leave', 'sick' => 'Sick leave (paid)', 'unpaid' => 'Unpaid leave' }.freeze
  STATUSES = %w[pending approved cancelled].freeze
  STATUS_LABELS = { 'pending' => 'Waiting for approval', 'approved' => 'Approved', 'cancelled' => 'Cancelled' }.freeze
  MAX_DAYS_BACK = 7 # leave can be applied for up to a week after it started

  belongs_to :team_member

  validates :kind, inclusion: { in: KINDS.keys }
  validates :from_date, :to_date, presence: true
  validates :reason, presence: true, length: { maximum: 500 }
  validates :status, inclusion: { in: STATUSES }
  validate :dates_in_order
  validate :has_a_working_day
  validate :not_too_far_back, on: :create
  validate :no_overlap, on: :create

  scope :approved, -> { where(status: 'approved') }
  scope :pending, -> { where(status: 'pending') }

  def kind_label = KINDS[kind]
  def status_label = STATUS_LABELS[status]
  def paid? = %w[paid sick].include?(kind)
  def covers?(date) = date.between?(from_date, to_date)

  # working days in the leave (Sundays are not counted when Sunday is the weekly off)
  def days
    return 0 unless from_date && to_date && from_date <= to_date

    off = AttendanceSetting.current.sunday_off
    (from_date..to_date).count { |date| !(off && date.sunday?) }
  end

  # the admin may change the type when approving (e.g. paid -> unpaid)
  def approve!(kind: nil)
    update!(status: 'approved', kind: kind.to_s.presence_in(KINDS.keys) || self.kind, decided_by: 'admin',
            decided_at: Time.current)
  end

  def cancel!(by:, note: nil)
    update!(status: 'cancelled', decided_by: by, admin_note: note.to_s.strip.presence, decided_at: Time.current)
  end

  private

  def dates_in_order
    errors.add(:to_date, 'cannot be before the first day') if from_date && to_date && to_date < from_date
  end

  def has_a_working_day
    return unless from_date && to_date && from_date <= to_date && days.zero?

    errors.add(:base,
               'These dates have no working day (only weekly offs)')
  end

  def not_too_far_back
    return unless from_date && from_date < Date.current - MAX_DAYS_BACK

    errors.add(:from_date,
               "is too long ago – leave can be applied for up to #{MAX_DAYS_BACK} days back")
  end

  def no_overlap
    return unless team_member_id && from_date && to_date

    clash = LeaveRequest.where(team_member_id: team_member_id, status: %w[pending approved])
                        .where('from_date <= ? AND to_date >= ?', to_date, from_date).exists?
    errors.add(:base, 'You already have a leave request for some of these days') if clash
  end
end
