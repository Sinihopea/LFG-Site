class UserController < ApplicationController
  before_action :set_user, only: [:show]

  # GET /login
  def login
    flash[:notice] = "Already logged in." and redirect_to root_url and return if logged_in?
  end

  # POST /login
  def login_check
    user = User.find_by(username: login_params[:username]).try(:authenticate, login_params[:password])

    unless user.nil? or !user # Nil if there's no results, false if failed authentication
      login_user(user)
      flash[:notice] = "Successfully logged in."
      redirect_to root_url
    else
      flash[:alert] = "Invalid username or password."
      render "login"
    end
  end

  # GET /logout
  def logout
    flash[:notice] = "Successfully logged out"
    logout_user and redirect_to root_url
  end
  
  # GET /signup
  def signup
    @user = User.new
  end

  # POST /signup
  def create
    @user = User.new(signup_params)

    respond_to do |format|
      if @user.save
        login_user(@user)
        format.html { redirect_to "/user/#{@user.username}", notice: 'User was successfully created.' }
        format.json { render action: 'show', status: :created, location: @user }
      else
        format.html { render action: 'signup' }
        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end

  # GET /account
  def my_account
    redirect_to root_url and return unless logged_in?
    @games = @current_user.games + [Game.new] # We always want there to be one empty field.
    @current_user.skills.build if @current_user.skills.empty?
  end

  # PATCH /account
  def update
    # Okay this is a wee bit dirty
    user_params = user_params()
    game_params = user_params["games"]
    user_params["display_name"] = nil if user_params["display_name"].blank?
    user_params.delete("games")
    # Blank skills should be destroyed.
    user_params["skills_attributes"].each_with_index {|x, i| user_params["skills_attributes"]["#{i}"]["_destroy"] = '1' if x[1]["category"].empty? } unless user_params["skills_attributes"].blank?
    @current_user.assign_attributes(user_params)
    # Fill out the game list of the user
    unless game_params.nil?
      games = game_params.map { |x| x[1]["name"].strip }.uniq(&:downcase).reject(&:empty?) # I would work on the hash directly but empty strings cause havoc
      @current_user.games = games.map { |x| Game.where("lower(name) = ?", x.downcase).first || Game.create(name: x) }
    end
    respond_to do |format|
      if @current_user.valid?
        @current_user.save
        format.html { redirect_to '/account', notice: 'User was successfully updated.' }
        format.json { head :no_content }
      else
        @games = @current_user.games + [Game.new]
        format.html { render action: 'my_account' }
        format.json { render json: @current_user.errors, status: :unprocessable_entity }
      end
    end
  end

  # GET /user/:id
  def show
  end

  # GET /search
  def search
    search_params = params.permit(:query, :filter, :page)

    unless search_params["query"].blank? and search_params["filter"].blank?
      @query = search_params["query"]
      @filter = search_params["filter"]
      @query_string = search_params.map{|x|"#{x[0]}=#{x[1]}"}.join("&")

      unless @query.blank?
        search = PgSearch.multisearch(@query).with_pg_search_rank

        # TODO: This can be optimized. Move the IDs into arrays, mass-search the arrays
        # Map the tags, merge the arrays, I'll do it later.
        @results = search.map do |res|
          case res.searchable_type
          when "Tag"
            Tag.includes(user: [:skills]).find(res.searchable_id).user
          else
            User.includes(:skills).find(res.searchable_id)
          end
        end
      else
        @results = User.order("display_name DESC, username DESC")
      end

      
      unless @filter.blank?
        # Oh jesus.
        @results = @results.map {|x| x if x.skills.map(&:category).include? @filter }.compact.sort do |x,y|
          # The higher the confidence, the higher the ranking.
          y.skills.to_a.select {|x| x.category == @filter }[0].confidence <=> x.skills.to_a.select {|x| x.category == @filter }[0].confidence
        end
      end

      per_page = 10
      count = @results.size
      @page_num = search_params["page"].to_i || 0
      offset = @page_num * per_page
      @num_of_pages = count / per_page
      start_num = 0 + offset
      @results = @results[start_num...start_num + per_page]
    end
  end

  private
    def set_user
      begin
        @user = User.find_by(username: params[:id]) or not_found
      rescue ActionController::RoutingError
        render :template => 'shared/not_found', :status => 404
      end
    end

    def login_params
      params.permit(:username, :password)
    end

    def signup_params
      params.require(:user).permit(:username, :password, :password_confirmation, :email)
    end

    def user_params
      params.require(:user).permit(:old_password, :password, :password_confirmation, :bio, :display_name, :avatar,
                                   {games: :name},
                                   skills_attributes: [:id, :category, :confidence])
    end
end