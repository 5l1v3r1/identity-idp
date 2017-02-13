module SignUp
  class CompletionsController < ApplicationController
    before_action :verify_confirmed, if: :loa3?

    def show
      if user_fully_authenticated? && session[:sp].present?
        analytics.track_event(
          Analytics::USER_REGISTRATION_AGENCY_HANDOFF_PAGE_VISIT,
          service_provider_attributes
        )
      else
        p '======='
        p 'WE ARE REDIRECTING TO LOGIN< I THINK'
        p '======='
        redirect_to new_user_session_url
      end
    end

    def update
      analytics.track_event(
        Analytics::USER_REGISTRATION_AGENCY_HANDOFF_COMPLETE,
        service_provider_attributes
      )
      redirect_to session[:saml_request_url]
    end

    private

    def verify_confirmed
      redirect_to verify_path if current_user.decorate.identity_not_verified?
    end

    def loa3?
      sp_session[:loa3] == true
    end

    def service_provider_attributes
      { loa3: sp_session[:loa3], service_provider_name: sp_session[:friendly_name] }
    end

    def sp_session
      session[:sp]
    end
  end
end
