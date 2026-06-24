class LigneAvoir < ApplicationRecord
  self.table_name = "ligne_avoir"

  belongs_to :organisation

  belongs_to :avoir,
             class_name: "Avoir",
             foreign_key: :avoir_id,
             inverse_of: :lignes_avoir

  before_validation :calculer_total_ht

  validates :designation, presence: true

  validates :quantite,
            presence: true,
            numericality: { greater_than: 0 }

  validates :prix_unitaire_ht,
            presence: true,
            numericality: { greater_than_or_equal_to: 0 }

  validates :taux_tva,
            presence: true,
            numericality: { greater_than_or_equal_to: 0 }

  validates :total_ht,
            presence: true,
            numericality: { greater_than_or_equal_to: 0 }

  validate :avoir_appartient_a_la_meme_organisation
  validate :avoir_modifiable

  after_save :recalculer_totaux_de_l_avoir
  after_destroy :recalculer_totaux_de_l_avoir

  before_destroy :empecher_suppression_si_avoir_emis

  private

  def calculer_total_ht
    return if quantite.blank? || prix_unitaire_ht.blank?

    self.total_ht = quantite * prix_unitaire_ht
  end

  def avoir_appartient_a_la_meme_organisation
    return if organisation.blank? || avoir.blank?

    if avoir.organisation_id != organisation_id
      errors.add(:avoir, "doit appartenir à la même organisation que la ligne")
    end
  end

  def avoir_modifiable
    return if avoir.blank?
    return if avoir.brouillon?

    errors.add(:avoir, "ne peut plus être modifié après émission")
  end

  def empecher_suppression_si_avoir_emis
    return if avoir.blank? || avoir.brouillon?

    errors.add(:avoir, "ne peut plus être modifié après émission")
    throw(:abort)
  end

  def recalculer_totaux_de_l_avoir
    return if avoir.blank?

    avoir.recalculer_totaux!
  end
end
