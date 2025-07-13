class EmailSearchService
  def initialize(user)
    @user = user
    @embedder = EmbeddingService.new
  end

  def search(query)
    embedding = @embedder.embed(query)
    return [] unless embedding

    Email
      .where(user: @user)
      .order(Arel.sql("embedding <#> #{embedding.to_pgvector}"))
      .limit(10)
  end
end
