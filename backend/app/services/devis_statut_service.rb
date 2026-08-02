# frozen_string_literal: true

# Machine à états SIMPLE et NON légale du devis : brouillon -> envoye ->
# accepte / refuse. Patron de STRUCTURE calqué sur
# FactureStatusTransitionPolicy (constante TRANSITIONS gelée EN CODE, jamais
# en base) — pas son contenu, qui répond à un problème bien plus complexe
# (statuts entrants PA, garde temporelle). Ici, une simple table suffit.
#
# Contrairement à PaiementService (où la légalité de la transition est
# vérifiée par le modèle via ActiveRecord::RecordInvalid), la légalité est
# vérifiée ICI explicitement et lève une erreur métier dédiée
# (TransitionInterditeError), destinée à un 422 explicite en étage B — jamais
# une exception silencieuse.
#
# Ne construit PAS l'API (étage B) : point d'entrée que le futur contrôleur
# appellera, sans aucune dépendance HTTP ici.
class DevisStatutService
  class TransitionInterditeError < StandardError; end

  TRANSITIONS = {
    "brouillon" => %w[envoye],
    "envoye"    => %w[accepte refuse]
  }.freeze

  def initialize(devis:, utilisateur:)
    @devis = devis
    @organisation = devis.organisation
    @utilisateur = utilisateur
  end

  # Le numéro DEV-ANNEE-xxxx est tiré ICI, à l'envoi — jamais à la création
  # (un devis brouillon n'a pas de numéro, comme une facture brouillon) et
  # jamais à l'acceptation. NumerotationService est le même service que celui
  # utilisé par FactureEmissionService/AvoirEmissionService (verrou advisory,
  # séquence sans trou par organisation/type/année) : "devis" est déjà dans
  # Numerotation::TYPES_DOCUMENT, aucune modification nécessaire là-dessus.
  def envoyer!
    transitionner!(vers: "envoye") do
      @devis.numero = NumerotationService.generer!(
        organisation: @organisation,
        type_document: "devis",
        date: Date.current
      )
    end
  end

  def accepter!
    transitionner!(vers: "accepte")
  end

  def refuser!
    transitionner!(vers: "refuse")
  end

  private

  def transitionner!(vers:)
    ActiveRecord::Base.transaction do
      @devis.lock!

      statut_actuel = @devis.statut

      unless TRANSITIONS.fetch(statut_actuel, []).include?(vers)
        raise TransitionInterditeError,
              "Transition #{statut_actuel} -> #{vers} interdite pour ce devis"
      end

      yield if block_given?

      @devis.statut = vers
      @devis.save!

      creer_evenement!(action: "devis_#{vers}")

      @devis
    end
  end

  def creer_evenement!(action:)
    EvenementDevis.create!(
      organisation_id: @organisation.id,
      devis_id: @devis.id,
      utilisateur_id: @utilisateur&.id,
      statut: @devis.statut,
      source: "interne",
      payload: {
        action: action,
        numero: @devis.numero
      }
    )
  end
end
