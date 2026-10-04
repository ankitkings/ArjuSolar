class RequestUpdate < ApplicationRecord
  belongs_to :service_request
  belongs_to :admin_user, optional: true
  belongs_to :team_member, optional: true

  def author_name
    admin_user&.email || team_member&.name
  end
end
