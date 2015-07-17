Rails.application.routes.draw do
  root 'feed#feed'

  get  'login', to: 'user#login'
  post 'login', to: 'user#login_check'
  get  'signup', to: 'user#signup'
  post 'signup', to: 'user#create'
  get  'logout', to: 'user#logout'
  get 'account', to: 'user#my_account'
  patch 'account', to: 'user#update'
  post 'new_post', to: 'feed#create'

  get 'search', to: 'user#search'

  get '/user/:user_id/:post_id', to: 'feed#show'
  post '/user/post/update', to: 'feed#update'
  post '/user/post/delete', to: 'feed#delete'

  namespace :user, path: 'user' do
    get '/forgot_password', action: 'forgot_password'
    post '/forgot_password', action: 'forgot_password_check'
    get '/forgot_password/:activation_id', action: 'reset_password'
    post '/forgot_password/:activation_id', action: 'reset_password_check'
    get ':id', action: 'show'
  end

  scope :ajax do
    namespace :user, path: 'user' do
      post 'hide', action: 'profile_hide'
    end
  end

  get 'terms', to: 'static#terms'
  get 'faq', to: 'static#faq'
  get 'privacy', to: 'static#privacy'
end
