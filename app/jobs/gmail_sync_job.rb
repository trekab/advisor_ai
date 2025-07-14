class GmailSyncJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find(user_id)
    Rails.logger.info("[GmailSyncJob] Starting email sync for User##{user_id} (#{user.email})")
    
    gmail = GmailClient.new(user)
    embedder = EmbeddingService.new
    
    emails_fetched = 0
    emails_created = 0
    emails_skipped = 0

    begin
      gmail.fetch_recent.each do |message|
        emails_fetched += 1
        
        next if ::Email.exists?(message_id: message.id)

        subject = header_value(message.payload.headers, 'Subject')
        from    = header_value(message.payload.headers, 'From')
        to      = header_value(message.payload.headers, 'To')
        body    = extract_body(message.payload)

        if body.blank?
          emails_skipped += 1
          next
        end

        embedding = embedder.embed(body)

        ::Email.create!(
          user: user,
          message_id: message.id,
          subject: subject,
          from: from,
          to: to,
          content: body,
          embedding: embedding
        )
        
        emails_created += 1
      end
      
      Rails.logger.info("[GmailSyncJob] Completed sync for User##{user_id}: #{emails_fetched} fetched, #{emails_created} created, #{emails_skipped} skipped")
      
      # Update user's last sync timestamp
      user.update!(last_email_sync_at: Time.current)
      
      # Send notification if new emails were found
      if emails_created > 0
        EmailNotificationJob.perform_later(user_id, emails_created)
      end
      
    rescue Google::Apis::AuthorizationError => e
      Rails.logger.error("[GmailSyncJob] Auth error for User##{user_id}: #{e.message}")
      # Could send notification to user to reconnect Google account
      raise
    rescue => e
      Rails.logger.error("[GmailSyncJob] Error syncing emails for User##{user_id}: #{e.class} - #{e.message}")
      raise
    end
  end

  private

  def header_value(headers, name)
    headers.find { |h| h.name.casecmp(name).zero? }&.value
  end

  def extract_body(payload)
    if payload.parts&.any?
      plain = payload.parts.find { |p| p.mime_type == 'text/plain' }
      decode(plain&.body&.data)
    else
      decode(payload.body.data)
    end
  end

  def decode(data)
    return "" unless data.present?
    Base64.urlsafe_decode64(data).force_encoding('UTF-8')
  rescue StandardError => e
    Rails.logger.warn("[GmailSyncJob] Failed to decode message body: #{e.message}")
    ""
  end
end
