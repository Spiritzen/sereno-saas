class LigneDevis < ApplicationRecord
  self.table_name = "ligne_devis"

  belongs_to :organisation
  belongs_to :devis,
             class_name: "Devis",
             foreign_key: :devis_id,
             inverse_of: :lignes_devis

  belongs_to :produit, optional: true

  before_validation :calculer_total_ht

  validates :designation, presence: true

  validates :quantite, presence: true, numericality: { greater_than: 0 }
  validates :prix_unitaire_ht, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :taux_tva, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :total_ht, presence: true, numericality: { greater_than_or_equal_to: 0 }

  validate :devis_appartient_a_la_meme_organisation
  validate :produit_appartient_a_la_meme_organisation

  after_save :recalculer_totaux_du_devis
  after_destroy :recalculer_totaux_du_devis

  private

  def calculer_total_ht
    return if quantite.blank? || prix_unitaire_ht.blank?

    self.total_ht = quantite * prix_unitaire_ht
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

  def recalculer_totaux_du_devis
    devis.recalculer_totaux!
  end
end