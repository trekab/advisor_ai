class User < ApplicationRecord
  has_many :instructions, dependent: :destroy
end
