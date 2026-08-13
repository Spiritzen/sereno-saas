# frozen_string_literal: true

# Relances v1b (planificateur, scan-and-send) — SEULE source de la décision
# « quel niveau de relance AUTO est dû maintenant pour cette facture, ou
# aucun ? ». Ni RelanceScannerJob ni RelanceEnvoiJob ne recalculent cette
# formule — les deux appellent ce service (cf. §3 execution_relances_v1b :
# "réutilise l'existant, aucune 2e formule").
#
# Trois garde-fous, TOUS requis, dans cet ordre :
#   1) Facture#relancable? (v1a, inchangé) — statut/échéance dépassée/reste
#      à payer > 0. Couvre déjà payée, annulée, soldée par avoir, etc.
#   2) le palier suivant existe et son délai depuis l'échéance est atteint ;
#      la progression du palier ne compte QUE les relances AUTO envoyées
#      (origine "planifie", statut "envoyee") — le manuel reste toujours
#      niveau 1 et ne fait jamais avancer l'échelle auto (voulu, cf. §1).
#   3) le cooldown est respecté depuis la DERNIÈRE relance toutes origines
#      confondues (Facture#derniere_relance_at, v1a) — un rappel manuel
#      récent retarde donc la prochaine relance auto : on ne double-contacte
#      pas le client.
class RelanceCadenceService
  # Jours après l'ÉCHÉANCE à partir desquels chaque palier devient dû.
  DELAIS_PALIERS_JOURS = { 1 => 7, 2 => 15, 3 => 30 }.freeze

  # Niveau 3 = dernier palier (cf. check_relances_niveau, DB). Une fois
  # envoyé, le planificateur s'arrête pour cette facture — jusqu'à
  # intervention humaine (relance manuelle, avoir, paiement...).
  NIVEAU_MAX = DELAIS_PALIERS_JOURS.keys.max

  # Écart minimum entre deux relances, quelles qu'elles soient (manuelle OU
  # auto) — décision Sébastien du 13/08/2026.
  COOLDOWN_JOURS = 7

  def initialize(facture:)
    @facture = facture
  end

  # Renvoie le niveau (1..NIVEAU_MAX) dû maintenant, ou nil si aucune
  # relance auto n'est due (facture non relançable, palier pas encore
  # atteint, échelle épuisée, ou cooldown pas encore écoulé).
  def niveau_du
    return nil unless @facture.relancable?

    niveau = prochain_niveau_auto
    return nil if niveau.nil?
    return nil unless palier_atteint?(niveau)
    return nil unless cooldown_respecte?

    niveau
  end

  private

  def prochain_niveau_auto
    dernier_niveau_auto_envoye =
      @facture.relances.where(origine: "planifie", statut: "envoyee").maximum(:niveau).to_i

    prochain = dernier_niveau_auto_envoye + 1
    prochain > NIVEAU_MAX ? nil : prochain
  end

  def palier_atteint?(niveau)
    return false if @facture.date_echeance.blank?

    Date.current >= @facture.date_echeance + DELAIS_PALIERS_JOURS.fetch(niveau)
  end

  def cooldown_respecte?
    derniere = @facture.derniere_relance_at
    return true if derniere.blank?

    Date.current >= derniere.to_date + COOLDOWN_JOURS
  end
end
