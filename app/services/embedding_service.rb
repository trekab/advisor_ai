class EmbeddingService
  def initialize
    @client = OpenAI::Client.new(access_token: 'ollama', uri_base: 'http://host.docker.internal:11434/v1')
  end

  def embed(text)
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
end
