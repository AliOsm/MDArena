class User < ApplicationRecord
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :validatable

  has_many :owned_projects, class_name: "Project", foreign_key: :owner_id, dependent: :destroy, inverse_of: :owner
  has_many :memberships, class_name: "ProjectMembership", dependent: :destroy
  has_many :projects, through: :memberships

  validates :name, presence: true
end
