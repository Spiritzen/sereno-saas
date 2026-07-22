class EvenementFacture < ApplicationRecord
  self.table_name = "evenement_facture"

  SOURCES = %w[interne pa webhook sandbox].freeze

  belongs_to :organisation
  belongs_to :facture
  belongs_to :utilisateur, optional: true

  validates :statut, presence: true, inclusion: { in: Facture::STATUTS }
  validates :source, presence: true, inclusion: { in: SOURCES }

  validate :facture_appartient_a_la_meme_organisation
  validate :utilisateur_appartient_a_la_meme_organisation

validate :empecher_update, on: :update
before_destroy :empecher_destroy

  private

  def facture_appartient_a_la_meme_organisation
    return if organisation.blank? || facture.blank?

    if facture.organisation_id != organisation_id
      errors.add(:facture, "doit appartenir à la même organisation que l'événement")
    end
  end

  def utilisateur_appartient_a_la_meme_organisation
    return if organisation.blank? || utilisateur.blank?

    if utilisateur.organisation_id != organisation_id
      errors.add(:utilisateur, "doit appartenir à la même organisation que l'événement")
    end
  end

  def empecher_update
    errors.add(:base, "Un événement de facture est append-only et ne peut pas être modifié")
    throw(:abort)
  end

def empecher_destroy
  errors.add(:base, "Un événement de facture est append-only et ne peut pas être supprimé")
  throw(:abort)
end
end
