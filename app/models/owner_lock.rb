# The owner's own password. The money pages (earnings, wallet, payroll, salary, payment setup, margins) open only after it is typed,
# and lock again after 15 minutes without use. It is not the admin's login password.
class OwnerLock < ApplicationRecord
  IDLE_MINUTES = 15
  MAX_FAILED = 5
  LOCK_MINUTES = 15

  has_secure_password
  validates :password, length: { minimum: 8, maximum: 72 }, allow_nil: true

  def self.current = first
  def self.set? = exists?

  # forgotten password: run in the server console  bin/rails runner 'OwnerLock.reset!'  and set a new one
  def self.reset! = delete_all

  def locked? = locked_until.present? && locked_until.future?

  def register_failure!
    attempts = failed_attempts + 1
    if attempts >= MAX_FAILED
      update_columns(failed_attempts: 0, locked_until: LOCK_MINUTES.minutes.from_now)
    else
      update_columns(failed_attempts: attempts)
    end
  end

  def clear_failures! = update_columns(failed_attempts: 0, locked_until: nil)
end
