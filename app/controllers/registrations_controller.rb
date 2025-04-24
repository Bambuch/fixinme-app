class RegistrationsController < Devise::RegistrationsController
  before_action :authenticate_user!, only: [:edit, :update, :destroy]

  protected

  def update_resource(resource, params)
    # Based on update_with_password()
    if params[:password].blank?
      params.delete(:password)
      params.delete(:password_confirmation) if params[:password_confirmation].blank?
    end

    if resource.update(params)
      resource.clean_up_passwords
      true
    else
      resource.errors.add(:base, t('devise.registrations.update_failed'))
      false
    end
  end

  def after_inactive_sign_up_path_for(resource)
    new_user_session_path
  end
end
