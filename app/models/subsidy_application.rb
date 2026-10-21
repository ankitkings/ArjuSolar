class SubsidyApplication < ApplicationRecord
  include ImageAttachment

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

  NEXT_STEPS = {
    "preparing"            => "Make the application on the portal",
    "applied"              => "Wait for the electricity company's approval (check the portal)",
    "feasibility_approved" => "Approved – the installation can start; then apply for the net meter",
    "net_meter_applied"    => "Wait for the inspection and the net meter fitting",
    "commissioned"         => "Submit the bank details on the portal",
    "bank_submitted"       => "Wait for the subsidy to be credited",
    "subsidy_received"     => "Done – subsidy received",
    "rejected"             => "Rejected – decide what to do",
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

  # The documents the portal needs. Ticked when collected; a photo / PDF of each can be kept here too.
  DOCUMENTS = {
    electricity_bill_received: { file: :electricity_bill_file, label: "Electricity bill",
                                 hint: "The latest bill. The consumer number and the name must be clearly visible." },
    roof_ownership_confirmed:  { file: :ownership_proof_file, label: "Own house / roof",
                                 hint: "Proof that the client owns the house or can use the roof, e.g. a property tax receipt or an ownership paper." },
    bank_account_confirmed:    { file: :bank_proof_file, label: "Aadhaar-linked bank account",
                                 hint: "First page of the passbook, or a bank statement, of the account that is linked to the client's Aadhaar. Do not photograph the Aadhaar card number." },
    cancelled_cheque_received: { file: :cancelled_cheque_file, label: "Cancelled cheque",
                                 hint: "A cheque of that same account with CANCELLED written across it." }
  }.freeze

  belongs_to :service_request
  has_one_attached :electricity_bill_file
  has_one_attached :ownership_proof_file
  has_one_attached :bank_proof_file
  has_one_attached :cancelled_cheque_file
  DOCUMENTS.each_value { |doc| validates_document doc[:file] }

  before_validation :tick_documents_with_files

  before_validation :default_received_amount
  before_save :stamp_date
  after_save :release_holds, if: :saved_change_to_status?

  validates :status, inclusion: { in: STATUSES }
  validates :portal_application_no, presence: { message: "is needed once the application has been made on the portal" },
                                    unless: -> { %w[preparing withdrawn].include?(status) }
  validates :rejection_reason, presence: { message: "is needed – write why it was rejected" }, if: -> { status == "rejected" }
  validates :received_amount, numericality: { greater_than: 0 }, if: -> { status == "subsidy_received" }
  validates :expected_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :received_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :dates_not_in_future

  scope :in_group, ->(group) { where(status: GROUP_STATUSES.fetch(group)) }

  # Starts an application for a request, pre-filled with the system size and the expected subsidy
  def self.start_for!(request)
    quote = request.accepted_quote || request.latest_quote
    kw = request.installation&.capacity_kw || quote&.capacity_kw
    create!(service_request: request, system_capacity_kw: kw, expected_amount: SubsidyScheme.current.amount_for(kw || 0))
  end

  def documents_complete? = DOCUMENTS.keys.all? { |flag| self[flag] }
  def collected_documents = DOCUMENTS.select { |flag, _| self[flag] }.values.map { |doc| doc[:label] }
  def missing_documents = DOCUMENTS.reject { |flag, _| self[flag] }.values.map { |doc| doc[:label] }

  # has the application got to this step (or further)?
  def reached?(step)
    FLOW.include?(status) && FLOW.index(status) >= FLOW.index(step)
  end

  # what the admin has to do now
  def next_step
    return "Collect the missing documents (#{missing_documents.to_sentence}), then apply on the portal" if status == "preparing" && !documents_complete?
    NEXT_STEPS[status]
  end

  def status_label = LABELS[status]
  def step_index = FLOW.index(status)
  def finished? = %w[subsidy_received rejected withdrawn].include?(status)

  private

  # the dates are things that already happened
  def dates_not_in_future
    DATE_FOR_STATUS.values.each do |column|
      value = self[column]
      errors.add(column, "cannot be in the future") if value && value > Date.current
    end
  end

  # Moving the application on releases the work that was waiting for it:
  #  DISCOM approved          -> the installation can be scheduled
  #  Installed, net meter ... -> the payment can start
  def release_holds
    request = service_request
    if request.installation_status == "waiting_for_approval" && request.installation_hold_reason.nil?
      note = InstallationScheduler.new(request).call
      request.updates.create!(status: request.status, progress: request.progress,
                              note: "The PM Surya Ghar application is approved by the electricity company, so the installation can start. #{note}")
    elsif request.installation_status == "waiting_for_net_meter" && request.payment_hold_reason.nil?
      request.advance!(to: "payment", note: "The net meter has been applied, so the payment can start")
    end
  end

  # an uploaded photo / PDF counts as "collected"
  def tick_documents_with_files
    DOCUMENTS.each { |flag, doc| self[flag] = true if public_send(doc[:file]).attached? }
  end

  # "Subsidy received" without an amount means the expected amount arrived
  def default_received_amount
    self.received_amount = expected_amount if status == "subsidy_received" && received_amount.blank? && expected_amount.to_f.positive?
  end

  def stamp_date
    column = DATE_FOR_STATUS[status]
    self[column] ||= Date.current if column && status_changed?
  end
end
