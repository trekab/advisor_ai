# Recurring job configuration
# This file configures jobs that run on a schedule

# Email sync every 15 minutes
recurring do
  EmailSyncSchedulerJob.perform_later
end.every(15.minutes)

# Calendar sync every hour
recurring do
  User.where.not(google_access_token: nil).find_each do |user|
    CalendarSyncJob.perform_later(user.id)
  end
end.every(1.hour)

# HubSpot sync every 2 hours (if we implement it)
# recurring do
#   User.where.not(hubspot_access_token: nil).find_each do |user|
#     HubspotSyncJob.perform_later(user.id)
#   end
# end.every(2.hours)

# Clean up old data weekly
recurring do
  # Delete emails older than 30 days
  Email.where('created_at < ?', 30.days.ago).delete_all
  
  # Delete old messages older than 90 days
  Message.where('created_at < ?', 90.days.ago).delete_all
  
  Rails.logger.info("[Recurring] Cleaned up old data")
end.every(1.week) 