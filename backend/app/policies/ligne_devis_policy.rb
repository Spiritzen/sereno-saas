# frozen_string_literal: true

# Miroir exact de LigneAvoirPolicy : rôle + tenant UNIQUEMENT. L'immutabilité
# d'un devis non-brouillon est garantie par le MODÈLE (LigneDevis#devis_modifiable,
# #empecher_suppression_si_devis_non_brouillon) : la violation remonte donc en
# 422 (erreur de validation), jamais en 403.
class LigneDevisPolicy < ApplicationPolicy
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
