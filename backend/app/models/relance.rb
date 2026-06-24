class Relance < ApplicationRecord
  CANAUX = %w[email courrier].freeze
  STATUTS = %w[planifiee envoyee echec].freeze

  belongs_to :organisation
  belongs_to :facture

  validates :niveau,
            presence: true,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 1,
              less_than_or_equal_to: 3
            }

  validates :canal, presence: true, inclusion: { in: CANAUX }
  validates :statut, presence: true, inclusion: { in: STATUTS }
  validates :date_planifiee, presence: true

  validate :facture_appartient_a_la_meme_organisation
  validate :facture_doit_etre_emise
  validate :facture_doit_etre_impayee
  validate :envoyee_at_requis_si_envoyee

  def planifiee?
    statut == "planifiee"
  end

  def envoyee?
    statut == "envoyee"
  end

  def echec?
    statut == "echec"
  end

  private

  def facture_appartient_a_la_meme_organisation
    return if organisation.blank? || facture.blank?

    if facture.organisation_id != organisation_id
      errors.add(:facture, "doit appartenir à la même organisation que la relance")
    end
  end

  def facture_doit_etre_emise
    return if facture.blank?

    unless facture.emise?
      errors.add(:facture, "doit être émise pour pouvoir être relancée")
    end
  end

  def facture_doit_etre_impayee
    return if facture.blank?
    return if facture.total_ttc.blank? || facture.montant_paye.blank?

    if facture.montant_paye >= facture.total_ttc
      errors.add(:facture, "est déjà totalement payée")
    end
  end

  def envoyee_at_requis_si_envoyee
    return unless statut == "envoyee"

    if envoyee_at.blank?
      errors.add(:envoyee_at, "est requis quand la relance est envoyée")
    end
  end
end
