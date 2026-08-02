# frozen_string_literal: true

# Miroir exact de EvenementPaiement (table séparée, pas de polymorphisme —
# convention confirmée du projet) : un devis n'a aucun canal externe (pas de
# PA, pas de webhook, jamais transmis), donc une SEULE source possible,
# comme pour un paiement. Append-only : garanti par les DEUX mêmes
# mécanismes qu'EvenementFacture/EvenementAvoir/EvenementPaiement, mot pour
# mot.
class EvenementDevis < ApplicationRecord
  self.table_name = "evenement_devis"

  SOURCES = %w[interne].freeze

  belongs_to :organisation
  belongs_to :devis
  belongs_to :utilisateur, optional: true

  validates :statut, presence: true, inclusion: { in: Devis::STATUTS - %w[expire] }
  validates :source, presence: true, inclusion: { in: SOURCES }

  validate :devis_appartient_a_la_meme_organisation
  validate :utilisateur_appartient_a_la_meme_organisation

  validate :empecher_update, on: :update
  before_destroy :empecher_destroy

  private

  def devis_appartient_a_la_meme_organisation
    return if organisation.blank? || devis.blank?

    if devis.organisation_id != organisation_id
      errors.add(:devis, "doit appartenir à la même organisation que l'événement")
    end
  end

  def utilisateur_appartient_a_la_meme_organisation
    return if organisation.blank? || utilisateur.blank?

    if utilisateur.organisation_id != organisation_id
      errors.add(:utilisateur, "doit appartenir à la même organisation que l'événement")
    end
  end

  def empecher_update
    errors.add(:base, "Un événement de devis est append-only et ne peut pas être modifié")
    throw(:abort)
  end

  def empecher_destroy
    errors.add(:base, "Un événement de devis est append-only et ne peut pas être supprimé")
    throw(:abort)
  end
end
