class CalendarSyncJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find(user_id)
    calendar = GoogleCalendarClient.new(user)
    
    # Sync events for the next 30 days
    events = calendar.list_events(time_max: 30.days.from_now.end_of_day)
    
    Rails.logger.info("[CalendarSyncJob] Synced #{events.count} calendar events for User##{user_id}")
    
    # You could store these in a local database if needed for faster access
    # For now, we'll just log the sync
    events.each do |event|
      Rails.logger.debug("[CalendarSyncJob] Event: #{event[:summary]} on #{event[:start_time]}")
    end
    
  rescue Google::Apis::AuthorizationError => e
    Rails.logger.error("[CalendarSyncJob] Auth error for User##{user_id}: #{e.message}")
    # Could send notification to user to reconnect Google account
  rescue => e
    Rails.logger.error("[CalendarSyncJob] Error syncing calendar for User##{user_id}: #{e.class} - #{e.message}")
    raise
  end
end 