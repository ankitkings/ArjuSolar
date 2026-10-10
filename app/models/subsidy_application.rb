class SubsidyApplication < ApplicationRecord
  # the steps of the official process, in order
  FLOW = %w[preparing applied feasibility_approved net_meter_applied commissioned bank_submitted subsidy_received].freeze
  STATUSES = (FLOW + %w[rejected withdrawn]).freeze

  LABELS = {
    "preparing"            => "Preparing documents",
    "applied"              => "Applied on portal",
    "feasibility_approved" => "DISCOM approved",
    "net_meter_applied"    => "Installed, net meter applied",
    "commissioned"         => "Commissioned (net meter fitted)",
    "bank_submitted"       => "Bank details submitted",
    "subsidy_received"     => "Subsidy received",
    "rejected"             => "Rejected",
    "withdrawn"            => "Not applying"
  }.freeze

  GROUP_STATUSES = {
    "received"     => %w[subsidy_received],
    "rejected"     => %w[rejected],
    "not_applying" => %w[withdrawn],
    "in_progress"  => %w[preparing applied feasibility_approved net_meter_applied commissioned bank_submitted]
  }.freeze

  # the date that is stamped automatically when a status is reached
  DATE_FOR_STATUS = {
    "applied" => :applied_on, "feasibility_approved" => :feasibility_on, "net_meter_applied" => :net_meter_on,
    "commissioned" => :commissioned_on, "bank_submitted" => :bank_submitted_on, "subsidy_received" => :received_on
  }.freeze

  belongs_to :service_request

  before_validation :default_received_amount
  before_save :stamp_date

  validates :status, inclusion: { in: STATUSES }
  validates :portal_application_no, presence: { message: "is needed once the application has been made on the portal" },
                                    unless: -> { %w[preparing withdrawn].include?(status) }
  validates :rejection_reason, presence: { message: "is needed – write why it was rejected" }, if: -> { status == "rejected" }
  validates :received_amount, numericality: { greater_than: 0 }, if: -> { status == "subsidy_received" }
  validates :expected_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :received_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :in_group, ->(group) { where(status: GROUP_STATUSES.fetch(group)) }

  # Starts an application for a request, pre-filled with the system size and the expected subsidy
  def self.start_for!(request)
    quote = request.accepted_quote || request.latest_quote
    kw = request.installation&.capacity_kw || quote&.capacity_kw
    create!(service_request: request, system_capacity_kw: kw, expected_amount: SubsidyScheme.current.amount_for(kw || 0))
  end

  def status_label = LABELS[status]
  def step_index = FLOW.index(status)
  def finished? = %w[subsidy_received rejected withdrawn].include?(status)

  private

  # "Subsidy received" without an amount means the expected amount arrived
  def default_received_amount
    self.received_amount = expected_amount if status == "subsidy_received" && received_amount.blank? && expected_amount.to_f.positive?
  end

  def stamp_date
    column = DATE_FOR_STATUS[status]
    self[column] ||= Date.current if column && status_changed?
  end
end
