# frozen_string_literal: true

# Orchestration transactionnelle du cycle de vie d'un paiement : chaque
# écriture (création, confirmation, annulation) est accompagnée d'un
# EvenementPaiement dans LA MÊME transaction — aucun événement orphelin,
# miroir du patron déjà en place pour AvoirEmissionService/EvenementAvoir.
#
# Ne construit PAS l'API (étage B) : point d'entrée que le futur contrôleur
# appellera, sans aucune dépendance HTTP ici. Les erreurs de validation
# (éligibilité de la facture, transition de statut, contenu verrouillé après
# confirmation) remontent naturellement via ActiveRecord::RecordInvalid,
# exactement comme AvoirsController le fait déjà pour Avoir.
class PaiementService
  def initialize(organisation:, utilisateur:)
    @organisation = organisation
    @utilisateur = utilisateur
  end

  # statut: "brouillon" (par défaut, librement éditable ensuite) ou
  # "confirme" (enregistrement direct d'un paiement déjà réel, sans étape
  # brouillon intermédiaire) — les deux sont des points de départ valides.
  def enregistrer!(facture:, attributs:, statut: "brouillon")
    ActiveRecord::Base.transaction do
      paiement = @organisation.paiements.new(
        attributs.merge(facture: facture, statut: statut)
      )

      paiement.save!
      creer_evenement!(paiement)
      paiement
    end
  end

  def confirmer!(paiement:)
    transitionner!(paiement, "confirme")
  end

  def annuler!(paiement:)
    transitionner!(paiement, "annule")
  end

  private

  def transitionner!(paiement, nouveau_statut)
    ActiveRecord::Base.transaction do
      paiement.lock!
      paiement.update!(statut: nouveau_statut)
      creer_evenement!(paiement)
      paiement
    end
  end

  def creer_evenement!(paiement)
    EvenementPaiement.create!(
      organisation_id: @organisation.id,
      paiement_id: paiement.id,
      utilisateur_id: @utilisateur&.id,
      statut: paiement.statut,
      source: "interne",
      payload: {
        montant: paiement.montant,
        methode_code: paiement.methode_code,
        date_encaissement: paiement.date_encaissement&.iso8601,
        reference: paiement.reference
      }
    )
  end
end
