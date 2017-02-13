module SignUp
  class RegistrationsController < ApplicationController
    include PhoneConfirmation

    before_action :confirm_two_factor_authenticated, only: [:destroy_confirm]
    before_action :require_no_authentication
    before_action :skip_session_expiration, only: [:show]
    prepend_before_action :disable_account_creation, only: [:new, :create]

    def show
      analytics.track_event(Analytics::USER_REGISTRATION_INTRO_VISIT)
    end

    def new
      ab_finished(:demo)

      session[:registering] = true
      @register_user_email_form = RegisterUserEmailForm.new
      @view_model = CancelActions.new(current_user: current_user, session: session)
      analytics.track_event(Analytics::USER_REGISTRATION_ENTER_EMAIL_VISIT)
    end

    def create
      @register_user_email_form = RegisterUserEmailForm.new

      result = @register_user_email_form.submit(permitted_params)

      analytics.track_event(Analytics::USER_REGISTRATION_EMAIL, result)

      if result[:success]
        process_successful_creation
      else
        render :new
      end
    end

    protected

    def require_no_authentication
      return unless current_user
      redirect_to after_sign_in_path_for(current_user)
    end

    def permitted_params
      params.require(:user).permit(:email)
    end

    def process_successful_creation
      user = @register_user_email_form.user
      create_user_event(:account_created, user) unless @register_user_email_form.email_taken?

      resend_confirmation = params[:user][:resend]
      session[:email] = user.email
      # TODO: document in PR why this was added
      # we need to handle the case in which a user is signing up, but does
      # not currently have an account i.e., the screen when they enter their email
      session.delete(:registering)

      redirect_to sign_up_verify_email_path(resend: resend_confirmation)
    end

    def disable_account_creation
      redirect_to root_path if AppSetting.registrations_disabled?
    end
  end
end
