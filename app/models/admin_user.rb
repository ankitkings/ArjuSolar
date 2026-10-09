class AdminUser < ApplicationRecord
  has_secure_password
  has_many :chat_memberships, as: :member, dependent: :destroy
  validates :email, presence: true, uniqueness: { case_sensitive: false }
  before_validation { self.email = email.to_s.strip.downcase }
end
