# Admin > Requests: the search box also finds the requests assigned to a team member.
# Type a member's name (or part of it) to see their requests; "admin" shows the requests with the Admin,
# "unassigned" the ones nobody has yet. Name, phone and e-mail still work as before.
module RequestSearch
  def index
    term = params[:q].to_s.strip
    params.delete(:q)                  # the page builds everything else (status filter, subsidy filter ...) as it always did
    super
    return if term.blank?

    params[:q] = term                  # so the search box keeps what was typed
    return unless @requests.respond_to?(:left_joins)

    conditions = ["service_requests.name LIKE :q", "service_requests.phone LIKE :q", "service_requests.email LIKE :q", "team_members.name LIKE :q"]
    conditions << "service_requests.assigned_to_admin = :yes" if term.casecmp?("admin")
    conditions << "(service_requests.team_member_id IS NULL AND service_requests.assigned_to_admin = :no)" if term.casecmp?("unassigned")
    like = "%#{ServiceRequest.sanitize_sql_like(term)}%"
    @requests = @requests.left_joins(:team_member).where(conditions.join(" OR "), q: like, yes: true, no: false)
  end
end
