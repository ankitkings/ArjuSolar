# A conversation between admins / teammates: a group or a personal (direct) chat.
class Chat < ApplicationRecord
  has_many :memberships, class_name: "ChatMembership", dependent: :destroy
  has_many :messages, class_name: "ChatMessage", dependent: :destroy

  validates :kind, inclusion: { in: %w[group direct] }
  validates :name, presence: true, length: { maximum: 60 }, if: :group?

  def group? = kind == "group"
  def direct? = kind == "direct"

  # The group everybody belongs to
  def self.everyone
    find_or_create_by!(system_key: "everyone") { |c| c.kind = "group"; c.name = "Everyone" }
  rescue ActiveRecord::RecordNotUnique
    find_by!(system_key: "everyone")
  end

  # The personal chat between two people (created the first time)
  def self.direct_between(a, b)
    key = [a, b].map { |u| "#{u.class.name}:#{u.id}" }.sort.join("|")
    find_by(direct_key: key) || create!(kind: "direct", direct_key: key).tap { |c| c.add_member(a); c.add_member(b) }
  rescue ActiveRecord::RecordNotUnique
    find_by!(direct_key: key)
  end

  # Everybody a person can chat with: admins, and teammates who can log in
  def self.people_for(user)
    teammates = TeamMember.where(active: true).where.not(email: nil).where.not(password_digest: [nil, ""]).order(:name).to_a
    (AdminUser.order(:email).to_a + teammates).reject { |p| p.class == user.class && p.id == user.id }
  end

  # "TeamMember:5" -> the record (only people who may chat)
  def self.person_from_key(key)
    type, id = key.to_s.split(":", 2)
    case type
    when "TeamMember" then TeamMember.find_by(id: id, active: true)
    when "AdminUser"  then AdminUser.find_by(id: id)
    end
  end

  def add_member(user)
    memberships.find_or_create_by!(member: user)
  rescue ActiveRecord::RecordNotUnique
    memberships.find_by(member: user)
  end

  def members = memberships.map(&:member).compact
  def other_member(me) = members.find { |m| !(m.class == me.class && m.id == me.id) }
end
