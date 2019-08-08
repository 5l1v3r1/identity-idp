module TwoFactorAuthentication
  class BackupCodeSelectionPresenter < SelectionPresenter
    def initialize(user)
      @user = user
      super(user&.backup_code_configurations&.first)
    end

    def method
      if MfaPolicy.new(@user).no_factors_enabled?
        :backup_code_only
      else
        :backup_code
      end
    end

    def recommended?
      false
    end
  end
end
