class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  before_action :set_current_user, if: :logged_in?

  private
    def set_title(page_title)
      @title = "#{page_title} — League For Gamers"
    end

    def logged_in?
      !!session[:user]
    end

    def login_user(user)
      session[:user] = user.id
    end

    def logout_user
      session.delete :user
    end

    def set_current_user
      @current_user ||= User.includes(:bans, role: [:permissions]).find session[:user]
      # Unban mechanism
      if @current_user.role.name == "banned" 
        if @current_user.bans.first.end_date != nil and @current_user.bans.first.end_date < Time.now 
          @current_user.role = @current_user.bans.first.role
          @current_user.save
        else
          @ban = @current_user.bans.first
        end
      end
    end

    def not_found
      raise ActionController::RoutingError.new('Not Found')
    end

    def required_log_in
      redirect_to '/signup' and return unless logged_in?
    end

    def required_logged_out
      redirect_to root_url and return if logged_in?
    end
end
