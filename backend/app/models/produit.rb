class Produit < ApplicationRecord
  belongs_to :organisation
  belongs_to :taux_tva, optional: true

  has_many :lignes_devis,
         class_name: "LigneDevis",
         foreign_key: :produit_id,
         dependent: :restrict_with_exception
  has_many :lignes_facture,
         class_name: "LigneFacture",
         foreign_key: :produit_id,
         dependent: :restrict_with_exception

  validates :designation, presence: true
  validates :prix_unitaire_ht, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :actif, inclusion: { in: [ true, false ] }

  validates :unite, inclusion: {
    in: [ "unité", "heure", "jour", "forfait" ]
  }, allow_blank: true

  validate :organisation_coherente_avec_taux_tva

  private

  def organisation_coherente_avec_taux_tva
    return if taux_tva.blank?

    if taux_tva.organisation_id != organisation_id
      errors.add(:taux_tva, "doit appartenir à la même organisation que le produit")
    end
  end
end
