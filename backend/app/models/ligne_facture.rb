class LigneFacture < ApplicationRecord
  self.table_name = "ligne_facture"

  belongs_to :organisation

  belongs_to :facture,
             class_name: "Facture",
             foreign_key: :facture_id,
             inverse_of: :lignes_facture

  belongs_to :produit, optional: true

  before_validation :calculer_montants

  validates :designation, presence: true
  validates :quantite, presence: true, numericality: { greater_than: 0 }
  validates :prix_unitaire_ht, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :taux_tva, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :montant_tva, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :total_ht, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :total_ttc, presence: true, numericality: { greater_than_or_equal_to: 0 }

  validate :facture_appartient_a_la_meme_organisation
  validate :produit_appartient_a_la_meme_organisation
  validate :facture_modifiable

  after_save :recalculer_totaux_de_la_facture
  after_destroy :recalculer_totaux_de_la_facture

  before_destroy :empecher_suppression_si_facture_emise

  private

def calculer_montants
  return if quantite.blank? || prix_unitaire_ht.blank? || taux_tva.blank?

  montants = FactureTotalsService.calculer_ligne(
    quantite: quantite,
    prix_unitaire_ht: prix_unitaire_ht,
    taux_tva: taux_tva
  )

  self.total_ht = montants[:total_ht]
  self.montant_tva = montants[:montant_tva]
  self.total_ttc = montants[:total_ttc]
end

  def facture_appartient_a_la_meme_organisation
    return if organisation.blank? || facture.blank?

    if facture.organisation_id != organisation_id
      errors.add(:facture, "doit appartenir à la même organisation que la ligne")
    end
  end

  def produit_appartient_a_la_meme_organisation
    return if produit.blank?

    if produit.organisation_id != organisation_id
      errors.add(:produit, "doit appartenir à la même organisation que la ligne")
    end
  end

  def facture_modifiable
    return if facture.blank?
    return if facture.brouillon?

    errors.add(:facture, "ne peut plus être modifiée après émission")
  end

  def empecher_suppression_si_facture_emise
    return if facture.blank? || facture.brouillon?

    errors.add(:facture, "ne peut plus être modifiée après émission")
    throw(:abort)
  end

  def recalculer_totaux_de_la_facture
    return if facture.blank?

    facture.recalculer_totaux!
  end
end
