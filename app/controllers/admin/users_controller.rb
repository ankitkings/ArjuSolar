module Admin
  # "Users" = customers who have submitted a request, grouped by phone number
  class UsersController < BaseController
    def index
      @users = ServiceRequest
        .select("phone, MAX(name) AS name, MAX(email) AS email, COUNT(*) AS requests_count, MIN(created_at) AS first_seen, MAX(created_at) AS last_seen")
        .group(:phone).order("last_seen DESC")
    end
  end
end
