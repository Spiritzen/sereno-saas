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
  belongs_to :facture, optional: true
  belongs_to :avoir, optional: true

  validates :provider, presence: true
  validates :cle_deduplication, presence: true, uniqueness: true
  validates :statut_brut, presence: true
  validates :received_at, presence: true
  validates :resultat, presence: true, inclusion: { in: RESULTATS }

  # V1.2c — miroir exact de TransmissionPa#un_seul_document_cible : exactement
  # un des deux (facture XOR avoir), jamais aucun, jamais les deux.
  validate :un_seul_document_cible
  validate :facture_appartient_a_la_meme_organisation
  validate :avoir_appartient_a_la_meme_organisation
  validate :transmission_pa_appartient_a_la_meme_organisation

  validate :empecher_update, on: :update
  before_destroy :empecher_destroy

  def document
    facture || avoir
  end

  private

  def un_seul_document_cible
    if facture.blank? && avoir.blank?
      errors.add(:base, "Un événement entrant PA doit concerner une facture ou un avoir")
    end

    if facture.present? && avoir.present?
      errors.add(:base, "Un événement entrant PA ne peut pas concerner une facture et un avoir en même temps")
    end
  end

  def facture_appartient_a_la_meme_organisation
    return if organisation.blank? || facture.blank?

    if facture.organisation_id != organisation_id
      errors.add(:facture, "doit appartenir à la même organisation que l'événement entrant")
    end
  end

  def avoir_appartient_a_la_meme_organisation
    return if organisation.blank? || avoir.blank?

    if avoir.organisation_id != organisation_id
      errors.add(:avoir, "doit appartenir à la même organisation que l'événement entrant")
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
