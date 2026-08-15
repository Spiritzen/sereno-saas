# frozen_string_literal: true

# Miroir de RelancePolicy (même raisonnement, mot pour mot) : générer ou
# révoquer un lien de partage vers un client est un acte commercial/
# opérationnel, pas une écriture comptable — le COMPTABLE (lecture finance)
# n'est pas autorisé. Le SUPER_ADMIN (rôle PLATEFORME, hors tenant) non plus :
# ce n'est pas lui qui partage une facture avec UN client d'UNE organisation.
# Seuls OWNER et MEMBRE restent autorisés.
class PortailFactureTokenPolicy < ApplicationPolicy
  def create?
    peut_gerer?
  end

  def destroy?
    peut_gerer?
  end

  private

  def peut_gerer?
    return false if utilisateur.blank?
    return false if Current.organisation.blank?

    owner? || membre?
  end
end
