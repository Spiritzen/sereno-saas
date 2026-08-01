# frozen_string_literal: true

# Miroir exact d'AvoirPolicy : rôle + tenant UNIQUEMENT. Aucune vérification
# d'état ici (pas de brouillon?/confirme?) — l'éligibilité « facture payable »
# et les transitions de statut vivent déjà dans le modèle/PaiementService
# (→ 422). Une policy qui vérifierait l'état transformerait une 422 (erreur
# métier) en 403 (refus d'accès) — dette n°21 déjà connue sur Avoir/Facture,
# volontairement NON reproduite ici (voir prompt_paiements_v1b_api.txt §3).
class PaiementPolicy < ApplicationPolicy
  def index?
    peut_lire?
  end

  def show?
    peut_lire? && meme_organisation?
  end

  def evenements?
    peut_lire? && meme_organisation?
  end

  def create?
    peut_modifier?
  end

  def confirmer?
    peut_modifier? && meme_organisation?
  end

  def annuler?
    peut_modifier? && meme_organisation?
  end

  class Scope < Scope
    def resolve
      return scope.none if utilisateur.blank?
      return scope.none if Current.organisation.blank?

      scope.where(organisation_id: Current.organisation.id)
    end
  end

  private

  def peut_lire?
    utilisateur.present? && Current.organisation.present?
  end

  def peut_modifier?
    return false unless peut_lire?

    super_admin? || owner? || comptable?
  end

  def meme_organisation?
    return false if record.blank?
    return false if Current.organisation.blank?

    record.organisation_id == Current.organisation.id
  end
end
