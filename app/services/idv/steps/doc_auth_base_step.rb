# rubocop:disable Metrics/ClassLength
module Idv
  module Steps
    class DocAuthBaseStep < Flow::BaseStep
      GOOD_RESULT = 1
      FYI_RESULT = 2

      def initialize(flow)
        super(flow, :doc_auth)
      end

      private

      def image
        uploaded_image = flow_params[:image]
        return uploaded_image if uploaded_image.present?
        DataUrlImage.new(flow_params[:image_data_url])
      end

      def front_image
        uploaded_image = flow_params[:front_image]
        return uploaded_image if uploaded_image.present?
        DataUrlImage.new(flow_params[:front_image_data_url])
      end

      def back_image
        uploaded_image = flow_params[:back_image]
        return uploaded_image if uploaded_image.present?
        DataUrlImage.new(flow_params[:back_image_data_url])
      end

      def doc_auth_client
        @doc_auth_client ||= begin
          case doc_auth_vendor
          when 'acuant'
            ::Acuant::AcuantClient.new
          when 'mock'
            ::DocAuthMock::DocAuthMockClient.new
          else
            raise "#{doc_auth_vendor} is not a valid doc auth vendor"
          end
        end
      end

      ##
      # The `acuant_simulator` config is deprecated. The logic to switch vendors
      # based on its value can be removed once FORCE_ACUANT_CONFIG_UPGRADE in
      # acuant_simulator_config_validation.rb has been set to true for at least
      # a deploy cycle.
      #
      def doc_auth_vendor
        vendor_from_config = Figaro.env.doc_auth_vendor
        if vendor_from_config.blank?
          return Figaro.env.acuant_simulator == 'true' ? 'mock' : 'acuant'
        end
        vendor_from_config
      end

      def idv_throttle_params
        [current_user.id, :idv_resolution]
      end

      def attempter_increment
        Throttler::Increment.call(*idv_throttle_params)
      end

      def attempter_throttled?
        Throttler::IsThrottled.call(*idv_throttle_params)
      end

      def idv_failure(result)
        attempter_increment
        if attempter_throttled?
          redirect_to idv_session_errors_failure_url
        else
          redirect_to idv_session_errors_warning_url
        end
        result
      end

      def save_proofing_components
        Db::ProofingComponent::Add.call(user_id, :document_check, 'acuant')
        Db::ProofingComponent::Add.call(user_id, :document_type, 'state_id')
        return unless liveness_checking_enabled?
        Db::ProofingComponent::Add.call(user_id, :liveness_check, 'acuant')
      end

      def extract_pii_from_doc(response)
        flow_session[:pii_from_doc] = response.pii_from_doc.merge(
          uuid: current_user.uuid,
          phone: current_user.phone_configurations.take&.phone,
        )
      end

      def user_id_from_token
        flow_session[:doc_capture_user_id]
      end

      def post_front_image
        return throttled_response if throttled_else_increment

        result = doc_auth_client.post_front_image(
          image: image.read,
          instance_id: flow_session[:instance_id],
        )
        add_cost(:acuant_front_image)
        result
      end

      def post_back_image
        return throttled_response if throttled_else_increment

        result = doc_auth_client.post_back_image(
          image: image.read,
          instance_id: flow_session[:instance_id],
        )
        add_cost(:acuant_back_image)
        result
      end

      def post_images
        return throttled_response if throttled_else_increment

        result = doc_auth_client.post_images(
          front_image: front_image.read,
          back_image: back_image.read,
          instance_id: flow_session[:instance_id],
        )
        add_cost(:acuant_front_image)
        add_cost(:acuant_back_image)
        result
      end

      def throttled
        redirect_to throttled_url
        [false, I18n.t('errors.doc_auth.acuant_throttle')]
      end

      def throttled_response
        redirect_to throttled_url
        ::Acuant::Response.new(
          success: false,
          errors: [I18n.t('errors.doc_auth.acuant_throttle')],
        )
      end

      def throttled_url
        return idv_session_errors_throttled_url unless @flow.class == Idv::Flows::RecoveryFlow
        idv_session_errors_recovery_throttled_url
      end

      def throttled_else_increment
        Throttler::IsThrottledElseIncrement.call(user_id, :idv_acuant)
      end

      def user_id
        current_user ? current_user.id : user_id_from_token
      end

      def add_cost(token)
        issuer = sp_session[:issuer].to_s
        Db::SpCost::AddSpCost.call(issuer, 2, token)
        Db::ProofingCost::AddUserProofingCost.call(user_id, token)
      end

      def sp_session
        session.fetch(:sp, {})
      end

      def mark_selfie_step_complete_unless_liveness_checking_is_enabled
        mark_step_complete(:selfie) unless liveness_checking_enabled?
      end

      def mark_document_capture_or_image_upload_steps_complete
        if Figaro.env.document_capture_step_enabled == 'true'
          mark_step_complete(:front_image)
          mark_step_complete(:back_image)
          mark_step_complete(:mobile_front_image)
          mark_step_complete(:mobile_back_image)
        else
          mark_step_complete(:document_capture)
        end
      end

      def liveness_checking_enabled?
        FeatureManagement.liveness_checking_enabled? && (no_sp? || sp_session[:ial2_strict])
      end

      def no_sp?
        sp_session[:issuer].blank?
      end

      def mobile?
        client = DeviceDetector.new(request.user_agent)
        client.device_type != 'desktop'
      end

      delegate :idv_session, :session, to: :@flow
    end
  end
end

# rubocop:enable Metrics/ClassLength
