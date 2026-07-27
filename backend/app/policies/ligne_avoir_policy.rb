# frozen_string_literal: true

# Rôle + tenant UNIQUEMENT — délibérément SANS vérification de statut
# brouillon, contrairement à LigneFacturePolicy (qui, elle, porte
# facture_brouillon? dans la policy : un choix plus ancien du projet). Ici,
# l'immutabilité d'un avoir non-brouillon est déjà garantie par le MODÈLE
# (LigneAvoir#avoir_modifiable, #empecher_suppression_si_avoir_emis) : la
# violation remonte donc naturellement en erreur de validation (422), jamais
# en refus d'accès (403) — cohérent avec la leçon du projet (policy = rôle+
# tenant ; éligibilité métier = modèle/service, jamais la policy).
class LigneAvoirPolicy < ApplicationPolicy
  def create?
    peut_modifier? && meme_organisation?
  end

  def update?
    peut_modifier? && meme_organisation?
  end

  def destroy?
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
