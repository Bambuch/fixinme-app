class ApplicationController < ActionController::Base
  # Turbo-rails disables layout rendering for turbo_frame requests (i.e.
  # requests that specify 'turbo-frame:' header).
  # As a side effect, this also disables layout for turbo_stream requests that
  # happen to originate from within turbo frame (e.g. turbo_frame_tag or tag
  # with 'is="turbo-frame"' attribute). To fix this, either frame tags must not be
  # used, or custom layout method needs to be defined.

  helper_method :current_user_disguised?
  helper_method :current_tab

  before_action :authenticate_user!

  class AccessForbidden < StandardError; end
  class ParameterInvalid < StandardError; end

  # Exceptions are handled depending on request format:
  # * HTML is handled by PublicExceptions, resulting in display of
  #   'public/<status-code>.html' template.
  # * TURBO_STREAM is handled by method specified below, which writes flash
  #   message and forces redirect to referer - to display flash and make page
  #   content consistent with database (which may or may not have been
  #   modified before exception).
  #   This requires referer to be available in TURBO_STREAM format. Otherwise
  #   Turbo will reload 2nd time with HTML format and flashes will be lost.
  rescue_from *ActionDispatch::ExceptionWrapper.rescue_responses.keys, with: :rescue_turbo

  protected

  def current_user_disguised?
    session[:revert_to_id].present?
  end

  def after_sign_in_path_for(scope)
    if current_user.at_least(:admin)
      users_path
    else
      edit_user_registration_path
    end
  end

  def after_sign_out_path_for(scope)
    new_user_session_path
  end

  class << self
    attr_reader :navigation_menu_tab
    def navigation_tab(name)
      @navigation_menu_tab = name.to_s
    end
  end
  def current_tab
    self.class.navigation_menu_tab || controller_name
  end

  private

  def rescue_turbo(exception)
    raise unless request.format.to_sym == :turbo_stream

    message_id = ActionDispatch::ExceptionWrapper.rescue_responses[exception.class.to_s]
    flash.alert = t("actioncontroller.exceptions.status.#{message_id}")
    redirect_to request.referer
  end

  def run_and_render(action)
    send action
    render action
  end
end
