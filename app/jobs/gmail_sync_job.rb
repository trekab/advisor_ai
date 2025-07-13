class GmailSyncJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find(user_id)
    gmail = GmailClient.new(user)
    embedder = EmbeddingService.new

    gmail.fetch_recent.each do |message|
      next if ::Email.exists?(message_id: message.id)

      subject = header_value(message.payload.headers, 'Subject')
      from    = header_value(message.payload.headers, 'From')
      to      = header_value(message.payload.headers, 'To')
      body    = extract_body(message.payload)

      next if body.blank?

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
    end
  rescue => e
    Rails.logger.error("[GmailSyncJob] Error syncing emails for User##{user_id}: #{e.class} - #{e.message}")
    raise
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
