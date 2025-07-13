class SessionsController < ApplicationController
  def index
  end

  def google_callback
    auth = request.env['omniauth.auth']
    user = User.find_or_initialize_by(email: auth.info.email)

    user.google_access_token = auth.credentials.token
    user.google_refresh_token = auth.credentials.refresh_token if auth.credentials.refresh_token.present?
    user.save!

    redirect_to root_path, notice: "Connected to Google as #{user.email}"
  end
end
