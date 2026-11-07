# A question and answer shown on the home page (Admin > Website)
class FaqItem < ApplicationRecord
  scope :active, -> { where(active: true) }
  scope :listed, -> { order(:position, :id) }

  before_validation do
    self.question = question.to_s.strip
    self.answer = answer.to_s.strip
  end

  validates :question, presence: true, length: { maximum: 200 }
  validates :answer, presence: true, length: { maximum: 1500 }
end
