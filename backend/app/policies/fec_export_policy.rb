# frozen_string_literal: true

# Export FEC (MVP, 15/08/2026) — rôle + tenant. OWNER et COMPTABLE autorisés
# (COMPTABLE = « lecture finance + exports comptables », c'est précisément
# son rôle — à la différence de Relance/Portail où le comptable est exclu :
# ici l'acte EST une écriture comptable, pas commercial). MEMBRE refusé.
# SUPER_ADMIN (rôle PLATEFORME, hors tenant) également refusé — même
# raisonnement que RelancePolicy/PortailFactureTokenPolicy : exporter la
# comptabilité d'UNE organisation est un acte posé par quelqu'un qui agit
# DANS l'organisation, jamais par un rôle plateforme.
#
# Pas de `record` réel ici (l'export n'est pas scopé à un enregistrement
# précis mais à l'organisation courante) — le contrôleur autorise via
# `authorize :fec_export, :creer?, policy_class: FecExportPolicy` (Pundit
# 2.5 accepte un symbole + policy_class explicite quand il n'y a pas
# d'enregistrement dont déduire le nom de policy).
class FecExportPolicy < ApplicationPolicy
  def creer?
    return false if utilisateur.blank?
    return false if Current.organisation.blank?

    owner? || comptable?
  end
end
