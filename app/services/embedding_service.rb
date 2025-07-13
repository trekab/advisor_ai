class EmbeddingService
  def initialize
    @client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
  end

  def embed(text)
    return nil if text.blank?

    retries = 0
    begin
      response = @client.embeddings(
        parameters: {
          model: "text-embedding-ada-002",
          input: text
        }
      )
      response.dig("data", 0, "embedding")
    rescue Faraday::TooManyRequestsError => e
      retries += 1
      if retries <= 3
        sleep(2 ** retries) # exponential backoff
        retry
      else
        Rails.logger.warn "[EmbeddingService] Gave up after 3 retries: #{e.message}"
        nil
      end
    rescue => e
      Rails.logger.error "[EmbeddingService] Failed to embed: #{e.class} - #{e.message}"
      nil
    end
  end
end
