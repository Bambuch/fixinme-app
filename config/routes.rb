Rails.application.routes.draw do
  devise_for :users, path: '', path_names: {registration: 'profile'},
    controllers: {registrations: :registrations}

  resources :units, except: [:show], path_names: {new: '(/:id)/new'} do
    member do
      post :rebase
    end
  end

  namespace :units do
    get 'defaults/index'
  end

  resources :users, only: [:index, :show, :update] do
    member do
      get :disguise
    end
    collection do
      get :revert
    end
  end

  devise_scope :user do
    root to: "devise/sessions#new"
  end
  get "redirect_to_repo", to: 'application#redirect_to_repo'
  get "redirect_to_issues", to: 'application#redirect_to_issues'
end
