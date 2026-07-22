# frozen_string_literal: true

# Ce que la PA AFFIRME (P1 du prompt B3.1a) — jamais ce que Sereno accepte.
# Toute notification distincte est conservée ici, quel que soit le résultat
# de la classification (applied/duplicate/stale/requires_review/unmapped),
# à l'exception du doublon strict (la ligne existante EST sa conservation).
#
# Append-only au niveau modèle, sur le modèle exact d'EvenementFacture :
# `resultat` est déterminé AVANT la création (jamais réécrit après coup).
class EvenementEntrantPa < ApplicationRecord
  self.table_name = "evenement_entrant_pa"

  RESULTATS = %w[applied duplicate stale requires_review unmapped].freeze

  belongs_to :organisation
  belongs_to :transmission_pa
  belongs_to :facture

  validates :provider, presence: true
  validates :cle_deduplication, presence: true, uniqueness: true
  validates :statut_brut, presence: true
  validates :received_at, presence: true
  validates :resultat, presence: true, inclusion: { in: RESULTATS }

  validate :facture_appartient_a_la_meme_organisation
  validate :transmission_pa_appartient_a_la_meme_organisation

  validate :empecher_update, on: :update
  before_destroy :empecher_destroy

  private

  def facture_appartient_a_la_meme_organisation
    return if organisation.blank? || facture.blank?

    if facture.organisation_id != organisation_id
      errors.add(:facture, "doit appartenir à la même organisation que l'événement entrant")
    end
  end

  def transmission_pa_appartient_a_la_meme_organisation
    return if organisation.blank? || transmission_pa.blank?

    if transmission_pa.organisation_id != organisation_id
      errors.add(:transmission_pa, "doit appartenir à la même organisation que l'événement entrant")
    end
  end

  def empecher_update
    errors.add(:base, "Un événement entrant PA est append-only et ne peut pas être modifié")
    throw(:abort)
  end

  def empecher_destroy
    errors.add(:base, "Un événement entrant PA est append-only et ne peut pas être supprimé")
    throw(:abort)
  end
end
