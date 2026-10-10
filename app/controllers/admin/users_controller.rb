module Admin
  # "Users" = clients who have submitted a request, grouped by phone number.
  # Editing or deleting a client applies to all of that client's requests.
  class UsersController < BaseController
    def index
      @users = ServiceRequest
        .select("phone, MAX(name) AS name, MAX(email) AS email, COUNT(*) AS requests_count, MIN(id) AS client_id, MIN(created_at) AS first_seen, MAX(created_at) AS last_seen")
        .group(:phone).order("last_seen DESC")
    end

    def edit
      load_client
    end

    def update
      load_client
      attrs = params.require(:client).permit(:name, :phone, :email)
      ServiceRequest.transaction { @requests.find_each { |r| r.update!(attrs) } }
      redirect_to admin_users_path, notice: "Client updated on #{@requests.count} request(s)"
    rescue ActiveRecord::RecordInvalid => e
      @error = e.record.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end

    # Deletes the client's requests and everything linked to them
    def destroy
      load_client
      count = @requests.count
      ServiceRequest.transaction { @requests.find_each(&:destroy!) }
      redirect_to admin_users_path, notice: "Client #{@sample.name} and #{count} request(s) deleted"
    rescue ActiveRecord::RecordNotDestroyed, ActiveRecord::InvalidForeignKey => e
      redirect_to admin_users_path, alert: "The client could not be deleted: #{e.message.truncate(160)}"
    end

    private

    # the id in the address is the client's first request; the client is everybody with that phone number
    def load_client
      @sample = ServiceRequest.find(params[:id])
      @requests = ServiceRequest.where(phone: @sample.phone)
    end
  end
end
