class Paiement < ApplicationRecord
  METHODES = %w[virement carte cheque especes prelevement].freeze

  belongs_to :organisation
  belongs_to :facture

  validates :montant,
            presence: true,
            numericality: { greater_than: 0 }

  validates :methode,
            presence: true,
            inclusion: { in: METHODES }

  validates :date_paiement, presence: true
  validates :reference, length: { maximum: 100 }, allow_blank: true

  validate :facture_appartient_a_la_meme_organisation
  validate :facture_doit_etre_emise
  validate :montant_total_paye_ne_depasse_pas_total_ttc

  after_save :recalculer_montant_paye_de_la_facture
  after_destroy :recalculer_montant_paye_de_la_facture

  private

  def facture_appartient_a_la_meme_organisation
    return if organisation.blank? || facture.blank?

    if facture.organisation_id != organisation_id
      errors.add(:facture, "doit appartenir à la même organisation que le paiement")
    end
  end

  def facture_doit_etre_emise
    return if facture.blank?

    unless facture.emise?
      errors.add(:facture, "doit être émise pour recevoir un paiement")
    end
  end

  def montant_total_paye_ne_depasse_pas_total_ttc
    return if facture.blank? || montant.blank?

    total_deja_paye = facture.paiements.where.not(id: id).sum(:montant)
    nouveau_total = total_deja_paye + montant

    if nouveau_total > facture.total_ttc
      errors.add(:montant, "ne peut pas dépasser le reste à payer de la facture")
    end
  end

  def recalculer_montant_paye_de_la_facture
    return if facture.blank?

    total_paye = facture.paiements.sum(:montant)

    nouveau_statut =
      if total_paye >= facture.total_ttc
        "encaissee"
      else
        facture.statut
      end

    facture.update!(
      montant_paye: total_paye,
      statut: nouveau_statut
    )
  end
end