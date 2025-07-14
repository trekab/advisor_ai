class EmbeddingService
  def initialize
    @client = OpenAI::Client.new(access_token: 'ollama', uri_base: 'http://host.docker.internal:11434/v1')
  end

  def embed_text(text)
    return nil if text.blank?
    
    begin
      response = @client.embeddings(
        parameters: {
          model: "nomic-embed-text",
          input: text
        }
      )
      
      embedding_data = response.dig("data", 0, "embedding")
      return nil unless embedding_data
      
      # Convert to pgvector format
      embedding_data
    rescue => e
      Rails.logger.error("[EmbeddingService] Error generating embedding: #{e.class} - #{e.message}")
      nil
    end
  end

  def embed_email(email)
    text = [
      email.subject,
      email.from,
      email.to,
      email.content
    ].compact.join("\n")
    
    embedding = embed_text(text)
    email.update(embedding: embedding) if embedding
  end

  def embed_hubspot_contact(contact_data)
    text = [
      contact_data[:first_name],
      contact_data[:last_name],
      contact_data[:email],
      contact_data[:company],
      contact_data[:notes]&.join("\n")
    ].compact.join("\n")
    
    embed_text(text)
  end

  def search_emails(query, user_id, limit: 5)
    query_embedding = embed_text(query)
    return [] unless query_embedding

    # Use pgvector similarity search
    Email.where(user_id: user_id)
         .where.not(embedding: nil)
         .order(Arel.sql("embedding <=> '#{query_embedding}'::vector"))
         .limit(limit)
  end

  def search_hubspot_data(query, user_id, limit: 5)
    query_embedding = embed_text(query)
    return [] unless query_embedding

    # For now, return recent contacts - in production you'd store embeddings
    user = User.find(user_id)
    return [] unless user.hubspot_access_token.present?

    client = HubspotClient.new(user)
    client.search_contacts(query, limit: limit)
  rescue => e
    Rails.logger.error("HubSpot search error: #{e.message}")
    []
  end
end
