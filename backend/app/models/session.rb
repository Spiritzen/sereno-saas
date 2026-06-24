class Session < ApplicationRecord
  belongs_to :utilisateur
  belongs_to :organisation

  validates :refresh_token_hash, presence: true, uniqueness: true
  validates :expire_at, presence: true
  validates :ip_adresse, length: { maximum: 45 }, allow_blank: true

  validate :organisation_coherente_avec_utilisateur

  def revoquee?
    revoque_at.present?
  end

  def expiree?
    expire_at <= Time.current
  end

  def active?
    !revoquee? && !expiree?
  end

  private

  def organisation_coherente_avec_utilisateur
    return if utilisateur.blank? || organisation.blank?

    if utilisateur.organisation_id != organisation_id
      errors.add(:organisation, "doit correspondre à l'organisation de l'utilisateur")
    end
  end
end