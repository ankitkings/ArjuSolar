# frozen_string_literal: true

# Attendance and leave belong to a team member (kept here so TeamMember itself stays as it is)
Rails.application.config.to_prepare do
  TeamMember.class_eval do
    has_many :attendances, dependent: :destroy
    has_many :leave_requests, dependent: :destroy
  end
end
