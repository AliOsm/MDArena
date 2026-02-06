class User < ApplicationRecord
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :validatable

  has_many :personal_access_tokens, dependent: :destroy

  validates :name, presence: true
end
