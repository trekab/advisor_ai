class EmailNotificationJob < ApplicationJob
  queue_as :default

  def perform(user_id, email_count)
    user = User.find(user_id)
    
    Rails.logger.info("[EmailNotificationJob] Sending notification to User##{user_id} about #{email_count} new emails")
    
    # For now, we'll just log the notification
    # In a production app, you might send:
    # - Email notifications
    # - Push notifications
    # - In-app notifications
    # - Slack/Discord webhooks
    
    Rails.logger.info("[EmailNotificationJob] User #{user.email} has #{email_count} new emails synced")
    
    # Example: Send email notification
    # UserMailer.new_emails_notification(user, email_count).deliver_now
    
    # Example: Send to notification service
    # NotificationService.new(user).send_email_alert(email_count)
    
  rescue => e
    Rails.logger.error("[EmailNotificationJob] Error sending notification to User##{user_id}: #{e.class} - #{e.message}")
    # Don't raise - notification failures shouldn't break the sync
  end
end 