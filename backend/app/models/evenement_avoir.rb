# frozen_string_literal: true

# Miroir exact de EvenementFacture (table séparée, pas de polymorphisme —
# style confirmé du projet). Append-only : garanti par les DEUX mêmes
# mécanismes qu'EvenementFacture, mot pour mot.
class EvenementAvoir < ApplicationRecord
  self.table_name = "evenement_avoir"

  SOURCES = %w[interne pa webhook sandbox].freeze

  belongs_to :organisation
  belongs_to :avoir
  belongs_to :utilisateur, optional: true

  validates :statut, presence: true, inclusion: { in: Avoir::STATUTS }
  validates :source, presence: true, inclusion: { in: SOURCES }

  validate :avoir_appartient_a_la_meme_organisation
  validate :utilisateur_appartient_a_la_meme_organisation

  validate :empecher_update, on: :update
  before_destroy :empecher_destroy

  private

  def avoir_appartient_a_la_meme_organisation
    return if organisation.blank? || avoir.blank?

    if avoir.organisation_id != organisation_id
      errors.add(:avoir, "doit appartenir à la même organisation que l'événement")
    end
  end

  def utilisateur_appartient_a_la_meme_organisation
    return if organisation.blank? || utilisateur.blank?

    if utilisateur.organisation_id != organisation_id
      errors.add(:utilisateur, "doit appartenir à la même organisation que l'événement")
    end
  end

  def empecher_update
    errors.add(:base, "Un événement d'avoir est append-only et ne peut pas être modifié")
    throw(:abort)
  end

  def empecher_destroy
    errors.add(:base, "Un événement d'avoir est append-only et ne peut pas être supprimé")
    throw(:abort)
  end
end
