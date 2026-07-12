# frozen_string_literal: true

class FacturePolicy < ApplicationPolicy
  def index?
    peut_lire?
  end

  def show?
    peut_lire? && meme_organisation?
  end

  def conformite?
  peut_lire? && meme_organisation?
  end

  def factur_x_xml?
    peut_lire? && meme_organisation?
  end

  def pdf?
  peut_lire? && meme_organisation?
  end

  def evenements?
    peut_lire? && meme_organisation?
  end

  def transmissions?
    peut_lire? && meme_organisation?
  end

  # Autorisation seulement : qui a le droit de déclencher une transmission
  # (rôle + tenant), pas SI la facture est éligible maintenant. L'éligibilité
  # (emise, ou déjà déposée pour un rejeu idempotent) est une règle métier à
  # granularité fine portée par TransmissionPaOrchestrationService, qui
  # renvoie une 422 explicite plutôt qu'un 403 générique.
  def transmettre?
    peut_modifier? && meme_organisation?
  end

  def create?
    peut_modifier?
  end

  def update?
    peut_modifier? && meme_organisation? && brouillon?
  end

  def destroy?
    peut_administrer? && meme_organisation? && brouillon?
  end

# Action prévue pour plus tard :
# passage d'une facture brouillon vers une facture émise.
def emettre?
  peut_modifier? && meme_organisation? && brouillon?
end

  # Action prévue pour plus tard :
  # archivage administratif, différent de destroy.
  def archive?
    peut_administrer? && meme_organisation?
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

  def brouillon?
    record.respond_to?(:brouillon?) && record.brouillon?
  end
end
