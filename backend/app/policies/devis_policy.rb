# frozen_string_literal: true

# Miroir exact d'AvoirPolicy : rôle + tenant UNIQUEMENT. AUCUN état métier
# ici (pas de dette n°21) — « le devis est-il brouillon / accepté / déjà
# converti ? » vit dans le modèle (Devis#empecher_modification_document_non_brouillon,
# #empecher_suppression_si_non_brouillon) et dans les services
# (DevisStatutService::TransitionInterditeError, DevisConversionService::ConversionImpossibleError),
# qui remontent une 422 explicite — jamais un 403 générique ici.
class DevisPolicy < ApplicationPolicy
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

  def update?
    peut_modifier? && meme_organisation?
  end

  def destroy?
    peut_administrer? && meme_organisation?
  end

  def envoyer?
    peut_modifier? && meme_organisation?
  end

  def accepter?
    peut_modifier? && meme_organisation?
  end

  def refuser?
    peut_modifier? && meme_organisation?
  end

  def convertir?
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

  def peut_administrer?
    return false unless peut_lire?

    super_admin? || owner?
  end

  def meme_organisation?
    return false if record.blank?
    return false if Current.organisation.blank?

    record.organisation_id == Current.organisation.id
  end
end
