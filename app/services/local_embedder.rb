class LocalEmbedder
  def initialize
    require 'llm'
    @llm = LLM::Embeddings.new(model: 'sentence-transformers/all-MiniLM-L6-v2')
  end

  def embed(text)
    return nil if text.blank?
    @llm.embed(text)
  end
end
