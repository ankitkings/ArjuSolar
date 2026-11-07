# Used by the Admin, Staff and Client-portal base controllers.
# A page that is opened by a person goes to the login page. A check running in the background
# (chat and alert polling) just gets "401" and never leaves a "Please log in" message in the
# session, which used to pop up later on whatever page was opened next.
module LoginGuard
  private

  def background_request?
    request.xhr? || request.format.json? || request.headers["Accept"].to_s.start_with?("application/json")
  end

  def deny_access(login_path, message: nil)
    return head(:unauthorized) if background_request?
    message ? redirect_to(login_path, alert: message) : redirect_to(login_path)
  end
end
