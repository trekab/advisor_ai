class SessionsController < ApplicationController
  def index
    redirect_to messages_path if current_user
  end

  def google_callback
    auth = request.env['omniauth.auth']
    user = User.find_or_initialize_by(email: auth.info.email)

    user.google_access_token = auth.credentials.token
    user.google_refresh_token = auth.credentials.refresh_token if auth.credentials.refresh_token.present?
    user.save!

    session[:user_id] = user.id
    
    # Trigger initial sync of emails and calendar
    GmailSyncJob.perform_later(user.id) if user.google_access_token.present?
    CalendarSyncJob.perform_later(user.id) if user.google_access_token.present?
    
    redirect_to messages_path, notice: "Connected to Google as #{user.email}. Syncing your emails and calendar..."
  end

  def failure
    error_message = case params[:message]
    when 'access_denied'
      'You denied access to your Google account. Please try again and grant the necessary permissions.'
    when 'invalid_credentials'
      'Invalid credentials. Please try logging in again.'
    else
      'Authentication failed. Please try again.'
    end
    
    redirect_to root_path, alert: error_message
  end

  def hubspot_auth
    oauth_client = HubspotOauthClient.new
    state = SecureRandom.hex(16)
    session[:hubspot_state] = state
    
    redirect_to oauth_client.authorization_url(state), allow_other_host: true
  end

  def hubspot_callback
    if params[:error]
      redirect_to messages_path, alert: "HubSpot authentication failed: #{params[:error]}"
      return
    end

    if params[:state] != session[:hubspot_state]
      redirect_to messages_path, alert: "Invalid state parameter. Please try again."
      return
    end

    begin
      oauth_client = HubspotOauthClient.new
      token_response = oauth_client.exchange_code_for_token(params[:code])
      
      current_user.update!(
        hubspot_access_token: token_response['access_token'],
        hubspot_refresh_token: token_response['refresh_token'],
        hubspot_token_updated_at: Time.current
      )
      
      session.delete(:hubspot_state)
      redirect_to messages_path, notice: "Connected to HubSpot successfully!"
    rescue => e
      Rails.logger.error("[SessionsController] HubSpot callback error: #{e.class} - #{e.message}")
      redirect_to messages_path, alert: "Failed to connect to HubSpot: #{e.message}"
    end
  end

  def logout
    session[:user_id] = nil
    redirect_to root_path, notice: 'Logged out successfully.'
  end
end
