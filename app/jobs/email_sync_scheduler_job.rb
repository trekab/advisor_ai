class EmailSyncSchedulerJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info("[EmailSyncSchedulerJob] Starting scheduled email sync for all users")
    
    # Find all users with Google access tokens
    users_with_google = User.where.not(google_access_token: nil)
    
    if users_with_google.empty?
      Rails.logger.info("[EmailSyncSchedulerJob] No users with Google access found")
      return
    end
    
    Rails.logger.info("[EmailSyncSchedulerJob] Found #{users_with_google.count} users to sync")
    
    users_with_google.each do |user|
      # Check if user has recent sync (within last 15 minutes)
      last_sync = user.emails.maximum(:created_at)
      
      if last_sync.nil? || last_sync < 15.minutes.ago
        Rails.logger.info("[EmailSyncSchedulerJob] Scheduling sync for User##{user.id} (#{user.email})")
        GmailSyncJob.perform_later(user.id)
      else
        Rails.logger.info("[EmailSyncSchedulerJob] Skipping User##{user.id} - recent sync at #{last_sync}")
      end
    end
    
    Rails.logger.info("[EmailSyncSchedulerJob] Completed scheduling email syncs")
  rescue => e
    Rails.logger.error("[EmailSyncSchedulerJob] Error scheduling email syncs: #{e.class} - #{e.message}")
    raise
  end
end 