# The stages of a request, which department owns each stage,
# and which buttons the stage owner sees.
class RequestWorkflow
  ACTIVE_STATUSES   = %w[pending contacted site_visit quote_sent installation].freeze
  FINISHED_STATUSES = %w[completed cancelled].freeze

  # status => department that does the work while the request is in this status
  DEPARTMENT = {
    "pending"      => "contact_person",
    "contacted"    => "contact_person",
    "site_visit"   => "site_visitor",
    "quote_sent"   => "site_visitor",
    "installation" => "installation"
  }.freeze

  AGREED   = { to: "site_visit", label: "Client agreed → send to site visit", style: "go" }.freeze
  REJECTED = { to: "cancelled",  label: "Client not agreed → cancel",         style: "stop" }.freeze

  # After the call the contact person picks the result; either way the request moves on.
  # ("contacted" is kept only for older requests that are already in that status.)
  # "installation" has no buttons: it ends with the installation-details form.
  ACTIONS = {
    "pending" => [AGREED, REJECTED],
    "contacted" => [AGREED, REJECTED],
    "site_visit" => [
      { to: "quote_sent", label: "Site visit done → quote sent", style: "go" },
      { to: "cancelled",  label: "Not feasible / client dropped → cancel", style: "stop" }
    ],
    "quote_sent" => [
      { to: "installation", label: "Client accepted quote → start installation", style: "go" },
      { to: "cancelled",    label: "Client declined quote → cancel",             style: "stop" }
    ]
  }.freeze

  def self.actions_for(status)
    ACTIONS.fetch(status, [])
  end

  def self.allowed?(from, to)
    actions_for(from).any? { |a| a[:to] == to }
  end

  def self.active_sql
    ACTIVE_STATUSES.map { |s| "'#{s}'" }.join(",")
  end
end
