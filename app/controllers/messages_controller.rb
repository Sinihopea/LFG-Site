class MessagesController < ApplicationController
  before_action :set_chat, only: [:show, :create_message]
  before_action :required_log_in
  
  # GET /messages
  def index
    @chats = Chat.includes(:private_messages, :users).find_by_sql ["SELECT chats.* FROM chats_users INNER JOIN chats ON chats_users.chat_id = chats.id WHERE chats_users.user_id = ?", @current_user.id]
  end

  # GET /messages/new
  # def new
  # end

  # PUT /messages
  def create_chat
    # Eck... not proud of this
    flash[:warning] = "You do not have permission to send messages" and redirect_to root_url and return unless @current_user.has_permission? "can_send_private_messages"
    message_params = params.require(:private_message).permit(:body, {user: :id})
    @users = User.find(message_params["user"].map { |x| x[1]["id"] })
    @users << @current_user
    chat = Chat.new(users: @users)
    chat.save
    @message = PrivateMessage.new(chat: @chat, body: message_params["body"], user: @current_user)
    chat.private_messages << @message
    respond_to do |format|
      if @message.valid?
        chat.save
        format.html { redirect_to "/messages/#{chat.id}" }
        format.json { head :no_content }
      else
        chat.delete
        @users = @users - [@current_user]
        format.html {
          flash[:alert] = @message.errors.full_messages.join("\n")
          render template: 'user/direct_message'
        }
        format.json { render json: @message.errors, status: :unprocessable_entity }
      end
    end
  end

  # GET /messages/:id
  def show
    set_title "Chat between #{@chat.users.map(&:username).join(", ")}"
  end

  # PUT /messages/:id
  def create_message
    flash[:warning] = "You do not have permission to send messages" and redirect_to root_url and return unless @current_user.has_permission? "can_send_private_messages"
    message_params = params.require(:private_message).permit(:body)
    message = PrivateMessage.new(body: message_params["body"], user: @current_user, chat: @chat)
    respond_to do |format|
      if message.valid?
        message.save
        format.html { redirect_to "/messages/#{@chat.id}" }
        format.json { head :no_content }
      else
        format.html { 
          flash[:alert] = message.errors.full_messages.join("\n")
          set_title "Chat between #{@chat.users.map(&:username).join(", ")}"
          render action: 'show' 
        }
        format.json { render json: @current_user.errors, status: :unprocessable_entity }
      end
    end
  end

  private
    def set_chat
      begin
        @chat = Chat.includes(:private_messages, :users).find_by(id: params[:id]) or not_found
        not_found unless @chat.users.include? @current_user
      rescue ActionController::RoutingError
        render :template => 'shared/not_found', :status => 404
      end
    end
end
