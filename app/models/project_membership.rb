class ProjectMembership < ApplicationRecord
  belongs_to :user
  belongs_to :project

  validates :role, inclusion: { in: %w[owner editor] }
  validates :user_id, uniqueness: { scope: :project_id }
end
