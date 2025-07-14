class DashboardController < ApplicationController
  before_action :require_login
  before_action :set_user

  def index
    @stats = {
      total_emails: @user.emails.count,
      total_messages: @user.messages.count,
      total_instructions: @user.instructions.count,
      recent_emails: @user.emails.where('created_at > ?', 24.hours.ago).count,
      recent_messages: @user.messages.where('created_at > ?', 24.hours.ago).count
    }
    
    @sync_status = {
      google_connected: @user.google_access_token.present?,
      hubspot_connected: @user.hubspot_access_token.present?,
      last_email_sync: @user.last_email_sync_at,
      last_calendar_sync: @user.hubspot_token_updated_at # Using this as proxy for calendar sync
    }
    
    @recent_emails = @user.emails.order(created_at: :desc).limit(5)
    @recent_messages = @user.messages.order(created_at: :desc).limit(5)
  end

  def sync_now
    if @user.google_access_token.present?
      GmailSyncJob.perform_later(@user.id)
      CalendarSyncJob.perform_later(@user.id)
      flash[:notice] = "Sync started. This may take a few minutes."
    else
      flash[:alert] = "Please connect your Google account first."
    end
    
    redirect_to dashboard_index_path
  end

  private

  def set_user
    @user = current_user
  end
end 