Rails.application.routes.draw do
  root 'home#index'
  devise_for :users

  # API
  namespace 'api' do
    namespace 'v1' do
      get 'signup/form_builder', to: 'signup#form_builder'
      
      resources :sessions, only: [:create]

      resources :users, only: [:index, :create, :show, :update, :destroy] do
        collection do
          post 'activate_account/:ctoken', to: 'users#activate_account'
          get :geo_location
        end
        member do
          post :signout
          post 'approve'
          post 'unapprove'
        end
      end
    end
  end
end
