# frozen_string_literal: true

# Solde d'encaissement d'une facture, entièrement DÉRIVÉ — rien n'est stocké
# sur Facture (montant_paye reste à 0, cf. contrainte gelée, voir
# app/services/factur_x_xml_service.rb lu en lecture seule). Calque le patron
# déjà en place pour le "reste dû après avoirs" (jusqu'ici calculé côté
# frontend uniquement, cf. rapportReconnaissancev1.txt du 31/07) en lui
# ajoutant les paiements confirmés, côté backend cette fois, pour être
# réutilisable par un futur endpoint (étage B) sans dupliquer la formule.
class PaiementSyntheseService
  Result = Struct.new(:reste_a_payer, :statut_encaissement_local, keyword_init: true)

  def initialize(facture:)
    @facture = facture
  end

  def call
    total_ttc = FactureTotalsService.decimal(@facture.total_ttc)
    somme_avoirs = FactureTotalsService.decimal(somme_avoirs_emis)
    somme_paiements = FactureTotalsService.decimal(somme_paiements_confirmes)

    reste_du_apres_avoirs = FactureTotalsService.arrondir_centimes(
      [ total_ttc - somme_avoirs, FactureTotalsService::ZERO ].max
    )

    # Trop-perçu (paiements > reste dû après avoirs) : ACCEPTÉ par défaut
    # (décision v1 à valider par Sébastien, cf. rapport) — le paiement réel
    # est enregistré tel quel, reste_a_payer PLANCHE à 0 plutôt que de
    # devenir négatif. Le surplus n'est ni surfacé ni remboursé ici
    # (trop-perçu/remboursement = v2).
    reste_a_payer = FactureTotalsService.arrondir_centimes(
      [ reste_du_apres_avoirs - somme_paiements, FactureTotalsService::ZERO ].max
    )

    Result.new(
      reste_a_payer: reste_a_payer,
      statut_encaissement_local: statut_encaissement_local(somme_paiements, reste_a_payer)
    )
  end

  private

  def somme_avoirs_emis
    @facture.avoirs.where.not(statut: "brouillon").sum(:total_ttc)
  end

  def somme_paiements_confirmes
    @facture.paiements.where(statut: "confirme").sum(:montant)
  end

  # DÉRIVÉ uniquement — n'écrit jamais facture.statut, qui reste le statut du
  # cycle de vie/transmission (dont le "encaissee" de la PA, strictement
  # distinct de ce statut d'encaissement LOCAL).
  def statut_encaissement_local(somme_paiements, reste_a_payer)
    return "non_payee" if somme_paiements.zero?
    return "soldee" if reste_a_payer.zero?

    "partielle"
  end
end
