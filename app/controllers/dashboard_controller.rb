class DashboardController < ApplicationController
  before_action :require_login
  before_action :set_user

  def index
    # Email Statistics
    @email_stats = {
      total_emails: @user.emails.count,
      recent_emails: @user.emails.where('created_at > ?', 7.days.ago).count,
      sync_status: @user.last_email_sync_at&.strftime('%B %d, %Y at %I:%M %p') || 'Never synced',
      sync_status_class: sync_status_class(@user.last_email_sync_at),
      top_senders: @user.emails.group(:from).count.sort_by { |_, count| -count }.first(3)
    }
    
    # Calendar Statistics
    @calendar_stats = {
      upcoming_meetings: upcoming_meetings_count,
      this_week_meetings: this_week_meetings_count,
      calendar_status: @user.google_access_token.present? ? 'Connected' : 'Not Connected',
      calendar_status_class: @user.google_access_token.present? ? 'connected' : 'disconnected'
    }
    
    # Task Statistics
    @task_stats = {
      pending_tasks: 0,  # Temporarily disabled
      completed_today: 0,  # Temporarily disabled
      total_tasks: 0,  # Temporarily disabled
      completion_rate: 0  # Temporarily disabled
    }
    
    # HubSpot Statistics
    @hubspot_stats = {
      status: @user.hubspot_access_token.present? ? 'Connected' : 'Not Connected',
      status_class: @user.hubspot_access_token.present? ? 'connected' : 'disconnected',
      last_sync: @user.last_hubspot_sync_at&.strftime('%B %d, %Y at %I:%M %p') || 'Never synced'
    }
    
    # AI Chat Statistics
    @chat_stats = {
      total_messages: @user.messages.count,
      recent_conversations: @user.messages.where('created_at > ?', 7.days.ago).count,
      instructions_count: @user.instructions.count
    }
    
    # Recent Activity
    @recent_emails = @user.emails.order(created_at: :desc).limit(5)
    @recent_messages = @user.messages.order(created_at: :desc).limit(5)
    @recent_tasks = []  # Temporarily disabled - empty array to avoid nil errors
    
    # Connection Status
    @connected_services = [@user.google_access_token.present?, @user.hubspot_access_token.present?].count(true)
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

  def sync_status_class(last_sync_at)
    return 'disconnected' unless last_sync_at
    
    if last_sync_at > 1.hour.ago
      'connected'
    elsif last_sync_at > 24.hours.ago
      'warning'
    else
      'disconnected'
    end
  end

  def upcoming_meetings_count
    return 0 unless @user.google_access_token.present?
    
    # This would need to be implemented when calendar events are stored
    # For now, return 0 as placeholder
    0
  end

  def this_week_meetings_count
    return 0 unless @user.google_access_token.present?
    
    # This would need to be implemented when calendar events are stored
    # For now, return 0 as placeholder
    0
  end

  # def calculate_completion_rate
  #   total = @user.tasks.count
  #   return 0 if total.zero?
  #   
  #   completed = @user.tasks.where(status: 2).count  # 2 = completed
  #   ((completed.to_f / total) * 100).round(1)
  # end
end 