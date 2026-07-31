# frozen_string_literal: true

# Miroir exact de EvenementAvoir (table séparée, pas de polymorphisme —
# convention confirmée du projet). Append-only : garanti par les DEUX mêmes
# mécanismes qu'EvenementAvoir/EvenementFacture, mot pour mot.
class EvenementPaiement < ApplicationRecord
  self.table_name = "evenement_paiement"

  # V1 = suivi seul, aucune transmission/notification externe pour un
  # paiement : une seule source possible aujourd'hui (action d'un
  # utilisateur dans l'application). Liste fermée, extensible plus tard
  # (ex. import bancaire, v2) sans rouvrir ce fichier au-delà d'ajouter une
  # valeur.
  SOURCES = %w[interne].freeze

  belongs_to :organisation
  belongs_to :paiement
  belongs_to :utilisateur, optional: true

  validates :statut, presence: true, inclusion: { in: Paiement::STATUTS }
  validates :source, presence: true, inclusion: { in: SOURCES }

  validate :paiement_appartient_a_la_meme_organisation
  validate :utilisateur_appartient_a_la_meme_organisation

  validate :empecher_update, on: :update
  before_destroy :empecher_destroy

  private

  def paiement_appartient_a_la_meme_organisation
    return if organisation.blank? || paiement.blank?

    if paiement.organisation_id != organisation_id
      errors.add(:paiement, "doit appartenir à la même organisation que l'événement")
    end
  end

  def utilisateur_appartient_a_la_meme_organisation
    return if organisation.blank? || utilisateur.blank?

    if utilisateur.organisation_id != organisation_id
      errors.add(:utilisateur, "doit appartenir à la même organisation que l'événement")
    end
  end

  def empecher_update
    errors.add(:base, "Un événement de paiement est append-only et ne peut pas être modifié")
    throw(:abort)
  end

  def empecher_destroy
    errors.add(:base, "Un événement de paiement est append-only et ne peut pas être supprimé")
    throw(:abort)
  end
end
