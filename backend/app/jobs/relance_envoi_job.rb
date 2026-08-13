# frozen_string_literal: true

# JOB UNITAIRE : envoie UNE relance auto à UN niveau. Enfilé par
# RelanceScannerJob (le scanner planifie), jamais appelé directement par un
# contrôleur — MIROIR de PaPollTransmissionJob (patron du projet).
#
# ⚠️ COULOIR UNIQUE : ce job appelle RelanceService — le MÊME service que le
# bouton manuel "Relancer" (v1a). Aucune règle de construction/envoi/
# journalisation n'est recalculée ici. Ce job ne fait QUE de la
# PLANIFICATION : re-vérifier que l'envoi est toujours dû, puis déléguer.
class RelanceEnvoiJob < ApplicationJob
  queue_as :default

  def perform(facture_id, niveau)
    facture = Facture.find_by(id: facture_id)
    return if facture.blank?

    # RE-VÉRIFIE : l'état a pu changer entre l'enfilage par le scanner et
    # l'exécution de ce job (la facture a pu être payée, un avoir émis, un
    # rappel manuel envoyé entre-temps qui retarde le cooldown...). Si le
    # niveau dû a changé (ou n'est plus dû du tout), NO-OP silencieux —
    # idempotent, jamais une erreur pour un simple changement d'état normal.
    return unless RelanceCadenceService.new(facture: facture).niveau_du == niveau

    # Garde applicative : aucune relance AUTO déjà "envoyee" à ce niveau.
    # index_relances_auto_unique_par_niveau (§2) reste le filet DB de
    # dernier recours si deux exécutions concurrentes de ce job passaient
    # malgré tout cette garde en même temps (cf. rescue ci-dessous).
    return if facture.relances.where(origine: "planifie", statut: "envoyee", niveau: niveau).exists?

    envoyer!(facture, niveau)
  end

  private

  def envoyer!(facture, niveau)
    RelanceService.new(organisation: facture.organisation).envoyer!(
      facture: facture,
      origine: "planifie",
      niveau: niveau,
      # Informatif (satisfait la validation "date_planifiee requise si
      # origine planifie") : la date d'échéance du PALIER, pas la date
      # d'exécution réelle du job.
      date_planifiee: facture.date_echeance + RelanceCadenceService::DELAIS_PALIERS_JOURS.fetch(niveau)
    )
  rescue ActiveRecord::RecordNotUnique
    # Limite ASSUMÉE (§5 execution_relances_v1b) : livraison "au moins une
    # fois". Deux exécutions concurrentes de ce job (même facture, même
    # niveau) ont pu toutes deux passer la garde applicative ci-dessus avant
    # que l'une des deux n'écrive sa Relance — l'index unique partiel refuse
    # alors le doublon au moment du `save!` DANS RelanceService. Le mail a
    # pu partir deux fois ; on ne journalise jamais un doublon. Rare
    # (fenêtre de course étroite), toléré pour du recouvrement — pas de
    # 2-phase commit pour v1b.
    Rails.logger.warn(
      "[RelanceEnvoiJob] doublon absorbé par index_relances_auto_unique_par_niveau " \
      "(facture_id=#{facture.id} niveau=#{niveau})"
    )
  end
end
