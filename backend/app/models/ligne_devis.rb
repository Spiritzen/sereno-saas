class LigneDevis < ApplicationRecord
  self.table_name = "ligne_devis"

  belongs_to :organisation
  belongs_to :devis,
             class_name: "Devis",
             foreign_key: :devis_id,
             inverse_of: :lignes_devis

  belongs_to :produit, optional: true

  before_validation :calculer_montants

  validates :designation, presence: true

  validates :quantite, presence: true, numericality: { greater_than: 0 }
  validates :prix_unitaire_ht, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :taux_tva, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :montant_tva, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :total_ht, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :total_ttc, presence: true, numericality: { greater_than_or_equal_to: 0 }

  validate :devis_appartient_a_la_meme_organisation
  validate :produit_appartient_a_la_meme_organisation
  validate :devis_modifiable

  after_save :recalculer_totaux_du_devis
  after_destroy :recalculer_totaux_du_devis

  before_destroy :empecher_suppression_si_devis_non_brouillon

  private

  # Miroir exact de LigneFacture#calculer_montants : FactureTotalsService est
  # GELÉ STRICT, on APPELLE sa méthode de classe pure (calculer_ligne), on ne
  # la modifie jamais. C'est ce qui garantit qu'un devis et la facture qui en
  # découlerait affichent le même total au centime (même conventions
  # BigDecimal / ROUND_HALF_UP).
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

  def devis_appartient_a_la_meme_organisation
    return if organisation.blank? || devis.blank?

    if devis.organisation_id != organisation_id
      errors.add(:devis, "doit appartenir à la même organisation que la ligne")
    end
  end

  def produit_appartient_a_la_meme_organisation
    return if produit.blank?

    if produit.organisation_id != organisation_id
      errors.add(:produit, "doit appartenir à la même organisation que la ligne")
    end
  end

  # Miroir de LigneAvoir#avoir_modifiable / LigneFacture#facture_modifiable :
  # une fois le devis envoyé, ses lignes sont figées (§3 étage B).
  def devis_modifiable
    return if devis.blank?
    return if devis.brouillon?

    errors.add(:devis, "ne peut plus être modifié après envoi")
  end

  def empecher_suppression_si_devis_non_brouillon
    return if devis.blank? || devis.brouillon?

    errors.add(:devis, "ne peut plus être modifié après envoi")
    throw(:abort)
  end

  def recalculer_totaux_du_devis
    devis.recalculer_totaux!
  end
end
