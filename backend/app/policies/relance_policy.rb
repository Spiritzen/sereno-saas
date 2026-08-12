# frozen_string_literal: true

# Miroir de PaiementPolicy (rôle + tenant UNIQUEMENT, aucune vérification
# d'état — cf. commentaire de PaiementPolicy) SAUF sur deux points délibérés :
# - le COMPTABLE (lecture finance) n'est PAS autorisé à relancer un client.
#   Relancer est un acte commercial/opérationnel, pas une écriture comptable —
#   contrairement aux paiements, où le comptable enregistre légitimement un
#   encaissement.
# - le SUPER_ADMIN (rôle PLATEFORME, hors tenant) n'est PAS autorisé non plus
#   (décision Sébastien, exécution du 12/08/2026, cf.
#   verif_relances_v1a_avant_execution.txt V6) : relancer un client est un
#   acte MÉTIER posé par quelqu'un qui agit DANS l'organisation, pas par un
#   rôle plateforme qui n'y agit jamais.
# Seuls OWNER et MEMBRE restent autorisés.
class RelancePolicy < ApplicationPolicy
  def create?
    peut_relancer?
  end

  class Scope < Scope
    def resolve
      return scope.none if utilisateur.blank?
      return scope.none if Current.organisation.blank?

      scope.where(organisation_id: Current.organisation.id)
    end
  end

  private

  def peut_relancer?
    return false if utilisateur.blank?
    return false if Current.organisation.blank?

    owner? || membre?
  end
end
