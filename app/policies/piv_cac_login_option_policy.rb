class PivCacLoginOptionPolicy
  def initialize(user)
    @user = user
  end

  def configured?
    user.x509_dn_uuid.present?
  end

  def enabled?
    configured?
  end

  def available?
    enabled? || user.identities.any?(&:piv_cac_available?)
  end

  private

  attr_reader :user
end
