class Project < ApplicationRecord
  belongs_to :owner, class_name: "User"

  has_many :memberships, class_name: "ProjectMembership", dependent: :destroy
  has_many :users, through: :memberships

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
end
