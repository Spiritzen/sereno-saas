# frozen_string_literal: true

# Compte, pour une organisation, le nombre de TRANSMISSIONS dont le DERNIER
# evenement_entrant_pa a resultat = "requires_review" (V1.1-B3.2, §1 du
# prompt — décision « piste A »).
#
# ⚠️ CE N'EST PAS un COUNT naïf sur resultat = "requires_review" : un total
# historique ne redescendrait jamais (une contradiction résolue par un
# `applied` plus récent resterait comptée pour toujours). On ne regarde que
# le DERNIER événement de chaque transmission — le badge monte quand une
# contradiction apparaît, redescend quand elle se résout.
#
# Ordre temporel : COALESCE(occurred_at, received_at) DESC — repris tel quel
# de PaStatusIngestionService#traiter_nouvelle_notification! (dernier_applique),
# pour ne jamais diverger de la notion d'ordre déjà utilisée par le couloir
# d'ingestion.
#
# LECTURE SEULE : aucune écriture sur evenement_entrant_pa (append-only,
# invariant n°5 — intact par construction, cette classe ne fait que lire).
class PaRequiresReviewCounter
  def self.call(...)
    new(...).call
  end

  def initialize(organisation:)
    @organisation = organisation
  end

  def call
    EvenementEntrantPa
      .from(derniers_evenements_par_transmission, :evenement_entrant_pa)
      .where(resultat: "requires_review")
      .count
  end

  private

  attr_reader :organisation

  # Un seul évènement retenu par transmission : le plus récent au sens de
  # COALESCE(occurred_at, received_at) DESC — DISTINCT ON s'appuie sur
  # PostgreSQL, déjà la seule base supportée par ce projet.
  def derniers_evenements_par_transmission
    EvenementEntrantPa
      .select("DISTINCT ON (transmission_pa_id) *")
      .where(organisation: organisation)
      .order(Arel.sql("transmission_pa_id, COALESCE(occurred_at, received_at) DESC"))
  end
end
