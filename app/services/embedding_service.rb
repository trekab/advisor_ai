class EmbeddingService
  def initialize
    @provider = if Rails.configuration.x.embedding.provider == :local
                  LocalEmbedder.new
                else
                  OpenAIEmbedder.new
                end
  end

  def embed(text)
    @provider.embed(text)
  end
end
