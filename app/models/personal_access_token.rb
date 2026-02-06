class PersonalAccessToken < ApplicationRecord
  belongs_to :user

  attr_reader :token

  before_create :generate_token_and_digest

  scope :active, -> { where(revoked_at: nil).where("expires_at IS NULL OR expires_at > ?", Time.current) }

  def self.authenticate(plain_token)
    digest = Digest::SHA256.hexdigest(plain_token)
    active.find_by(token_digest: digest)
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  private

  def generate_token_and_digest
    @token = SecureRandom.base58(24)
    self.token_digest = Digest::SHA256.hexdigest(@token)
    self.token_prefix = @token[0, 8]
  end
end
