class AdminUser < ApplicationRecord
  has_secure_password
  validates :email, presence: true, uniqueness: { case_sensitive: false }
  before_validation { self.email = email.to_s.strip.downcase }
end
