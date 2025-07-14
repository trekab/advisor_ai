class User < ApplicationRecord
  has_many :instructions, dependent: :destroy
  has_many :messages, dependent: :destroy
  has_many :emails, dependent: :destroy
  has_many :tasks, dependent: :destroy
end
