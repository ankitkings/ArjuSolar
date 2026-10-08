# Chat for both panels. Admin::ChatsController and Staff::ChatsController include this and say
# who the chat user is (chat_user) and which panel's routes to use (chat_namespace).
module ChatActions
  extend ActiveSupport::Concern

  included do
    helper_method :chat_user, :chats_path_for, :chat_path_for, :poll_path_for, :send_path_for,
                  :direct_path_for, :new_chat_path_for
  end

  # Opens the shared "Everyone" group
  def index
    everyone = Chat.everyone
    everyone.add_member(chat_user)
    redirect_to chat_path_for(everyone)
  end

  def show
    load_sidebar
    @chat = find_chat
    @messages = @chat.messages.includes(:sender).order(:id).last(200)
    mark_read(@chat)
    render "chats/show"
  end

  # Form: new group chat
  def new
    load_sidebar_people
    render "chats/new"
  end

  def create
    members = Array(params[:member_keys]).filter_map { |key| Chat.person_from_key(key) }
                                          .reject { |p| p.class == chat_user.class && p.id == chat_user.id }
    chat = Chat.new(kind: "group", name: params[:name].to_s.strip)
    if members.empty?
      @error = "Pick at least one person for the group."
    elsif !chat.valid?
      @error = chat.errors.full_messages.to_sentence
    end
    if @error
      load_sidebar_people
      return render("chats/new", status: :unprocessable_entity)
    end

    Chat.transaction do
      chat.save!
      chat.add_member(chat_user)
      members.each { |m| chat.add_member(m) }
    end
    redirect_to chat_path_for(chat), notice: "Group created"
  end

  # Start (or reopen) a personal chat
  def direct
    person = Chat.person_from_key(params[:who])
    if person.nil? || (person.class == chat_user.class && person.id == chat_user.id)
      return redirect_to(chats_path_for, alert: "Choose someone to chat with.")
    end
    redirect_to chat_path_for(Chat.direct_between(chat_user, person))
  end

  # The browser asks every few seconds: any messages newer than ?after=ID ?
  def poll
    chat = find_chat
    messages = chat.messages.includes(:sender).where("chat_messages.id > ?", params[:after].to_i).order(:id).limit(100).to_a
    rendered = messages.map { |m| { id: m.id, html: render_to_string(partial: "chats/message", formats: [:html], locals: { message: m, me: chat_user }) } }
    mark_read(chat) if messages.any?
    render json: { messages: rendered }
  end

  def send_message
    chat = find_chat
    message = chat.messages.build(sender: chat_user, body: params[:body].to_s.strip)
    if message.save
      chat.memberships.where(member_type: chat_user.class.name, member_id: chat_user.id).update_all(last_read_message_id: message.id)
      if request.format.json?
        render json: { id: message.id, html: render_to_string(partial: "chats/message", formats: [:html], locals: { message: message, me: chat_user }) }
      else
        redirect_to chat_path_for(chat)
      end
    elsif request.format.json?
      render json: { error: message.errors.full_messages.to_sentence }, status: :unprocessable_entity
    else
      redirect_to chat_path_for(chat), alert: message.errors.full_messages.to_sentence
    end
  end

  # Number shown on the sidebar badge
  def unread
    render json: { count: ChatMessage.unread_counts_for(chat_user).values.sum }
  end

  # Checked every few seconds on every page: new messages from other people, in any of my chats,
  # since ?after=ID. Without ?after it only returns where things stand now (so old messages never pop up).
  def notifications
    mine = ChatMessage.joins(chat: :memberships)
                      .where(chat_memberships: { member_type: chat_user.class.name, member_id: chat_user.id })
    latest = mine.maximum("chat_messages.id").to_i
    items = []
    if params[:after].present?
      messages = mine.where.not(sender_type: chat_user.class.name, sender_id: chat_user.id)
                     .where("chat_messages.id > ?", params[:after].to_i)
                     .order("chat_messages.id").limit(10).preload(:sender, :chat).to_a
      latest = messages.last.id if messages.size >= 10     # more are waiting: carry on from here next time
      items = messages.map do |m|
        { id: m.id, chat_id: m.chat_id, sender: helpers.person_name(m.sender),
          group: (m.chat.name if m.chat.group?), preview: m.body.to_s.truncate(120), url: chat_path_for(m.chat) }
      end
    end
    render json: { latest: latest, messages: items, unread: ChatMessage.unread_counts_for(chat_user).values.sum }
  end

  private

  def chats_path_for      = send("#{chat_namespace}_chats_path")
  def chat_path_for(chat) = send("#{chat_namespace}_chat_path", chat)
  def poll_path_for(chat) = send("poll_#{chat_namespace}_chat_path", chat)
  def send_path_for(chat) = send("send_message_#{chat_namespace}_chat_path", chat)
  def direct_path_for     = send("direct_#{chat_namespace}_chats_path")
  def new_chat_path_for   = send("new_#{chat_namespace}_chat_path")

  # only chats this person belongs to
  def my_chats
    Chat.joins(:memberships).where(chat_memberships: { member_type: chat_user.class.name, member_id: chat_user.id })
  end

  def find_chat
    my_chats.find(params[:id])
  end

  def load_sidebar
    Chat.everyone.add_member(chat_user)   # new people are added to the shared group automatically
    @chats = my_chats.preload(memberships: :member).order(updated_at: :desc).to_a
    @chats.sort_by! { |c| [c.system_key == "everyone" ? 0 : 1, -c.updated_at.to_i] }
    @unread = ChatMessage.unread_counts_for(chat_user)
    load_sidebar_people
  end

  def load_sidebar_people
    @people = Chat.people_for(chat_user)
  end

  def mark_read(chat)
    last_id = chat.messages.maximum(:id)
    return unless last_id
    chat.memberships.where(member_type: chat_user.class.name, member_id: chat_user.id).update_all(last_read_message_id: last_id)
  end
end
