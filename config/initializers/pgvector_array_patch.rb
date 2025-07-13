class Array
  def to_pgvector
    "'[#{self.join(',')}]'"
  end
end
