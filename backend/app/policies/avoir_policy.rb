# frozen_string_literal: true

# Miroir exact de FacturePolicy : rôle + tenant UNIQUEMENT. La règle
# d'éligibilité métier « la facture cible doit être émise » vit déjà dans le
# modèle (Avoir#facture_deja_emise, V1.2a) et dans AvoirConformiteService —
# jamais ici. Une policy qui vérifierait l'état de la facture référencée
# transformerait une 422 (erreur métier) en 403 (refus d'accès) — leçon du
# projet, déjà appliquée sur transmettre?/synchroniser?/relancer?.
class AvoirPolicy < ApplicationPolicy
  def index?
    peut_lire?
  end

  def show?
    peut_lire? && meme_organisation?
  end

  def evenements?
    peut_lire? && meme_organisation?
  end

  def transmissions?
    peut_lire? && meme_organisation?
  end

  def pdf?
    peut_lire? && meme_organisation?
  end

  def avoir_x_xml?
    peut_lire? && meme_organisation?
  end

  def create?
    peut_modifier?
  end

  def emettre?
    peut_modifier? && meme_organisation? && brouillon?
  end

  # V1.2c — miroir exact de FacturePolicy#transmettre?/#synchroniser? : rôle
  # + tenant UNIQUEMENT. L'éligibilité métier (l'avoir doit être émis pour
  # être transmis, une transmission déposée doit exister pour synchroniser)
  # vit dans TransmissionPaOrchestrationService/PaStatusIngestionService, qui
  # remontent une 422 explicite — jamais un 403 générique ici.
  def transmettre?
    peut_modifier? && meme_organisation?
  end

  def synchroniser?
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

  def brouillon?
    record.respond_to?(:brouillon?) && record.brouillon?
  end
end
