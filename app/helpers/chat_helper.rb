module ChatHelper
  def person_name(user)
    case user
    when TeamMember then user.name
    when AdminUser  then "Admin (#{user.email.to_s.split('@').first})"
    else "Former teammate"
    end
  end

  def person_subtitle(user)
    case user
    when TeamMember then user.department_label
    when AdminUser  then "Admin"
    else ""
    end
  end

  def person_key(user) = "#{user.class.name}:#{user.id}"

  # a personal chat is titled with the other person's name
  def chat_title(chat, me)
    chat.direct? ? person_name(chat.other_member(me)) : chat.name
  end

  def chat_unread_count(user)
    @_chat_unread ||= ChatMessage.unread_counts_for(user).values.sum
  end
end
