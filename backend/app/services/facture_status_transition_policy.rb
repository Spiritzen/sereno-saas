# frozen_string_literal: true

# Le JUGE : décide si une notification de la PA peut être acceptée comme
# transition métier de la Facture.
#
# ⚠️ CE N'EST PAS une Pundit::Policy (aucune notion de rôle/permission —
# app/policies est réservé à l'autorisation Pundit dans ce projet, cf.
# FacturePolicy). C'est une machine d'état métier pure : elle vit donc dans
# app/services, comme les autres services métier (FactureConformiteService,
# NumerotationService...). Le nom reste FactureStatusTransitionPolicy pour
# rester fidèle au vocabulaire de la roadmap.
#
# Fonction PURE : aucune écriture, aucune lecture DB. La garde temporelle
# (occurred_at effectif, dernier occurred_at appliqué) est calculée par
# l'APPELANT (PaStatusIngestionService) et passée en argument — c'est ce qui
# rend cette classe triviale à tester en isolation, sans DB ni transmission.
#
# La table des transitions est gelée EN CODE (jamais en base) : un UPDATE
# accidentel ne doit jamais pouvoir autoriser une transition juridiquement
# incohérente.
class FactureStatusTransitionPolicy
  TRANSITIONS = {
    "deposee"            => %w[recue mise_a_disposition approuvee encaissee refusee en_litige],
    "recue"              => %w[mise_a_disposition approuvee encaissee refusee en_litige],
    "mise_a_disposition" => %w[approuvee encaissee refusee en_litige],
    "approuvee"          => %w[encaissee en_litige],
    "en_litige"          => %w[approuvee refusee encaissee],
    "refusee"            => [],
    "encaissee"          => [],
    "annulee"            => [],
    "archivee"           => []
  }.freeze

  # États depuis lesquels une transition ABSENTE de la table est une
  # CONTRADICTION (requires_review) plutôt qu'un simple vieux message (stale).
  TERMINAUX = %w[encaissee refusee annulee archivee].freeze

  RESULTATS = %w[applied duplicate stale requires_review unmapped].freeze

  Decision = Struct.new(:resultat, :motif, keyword_init: true) do
    def applied?
      resultat == "applied"
    end
  end

  def self.call(...)
    new(...).call
  end

  def initialize(statut_facture_actuel:, statut_candidat:, occurred_at:, dernier_occurred_at_applique:)
    @statut_facture_actuel = statut_facture_actuel
    @statut_candidat = statut_candidat
    @occurred_at = occurred_at
    @dernier_occurred_at_applique = dernier_occurred_at_applique
  end

  # L'ORDRE COMPTE — ne pas réarranger sans relire P4 du prompt B3.1a :
  #   1. mapping impossible               -> unmapped
  #   2. garde temporelle (AVANT la table) -> stale
  #   3. aucun changement de statut        -> stale
  #   4. transition présente dans la table -> applied
  #   5. transition absente : terminal ? requires_review : stale
  def call
    return decision("unmapped", "Statut fournisseur non reconnu (mapping impossible)") if @statut_candidat.nil?

    if notification_perimee?
      return decision(
        "stale",
        "Notification antérieure à la dernière observation appliquée sur cette transmission"
      )
    end

    if @statut_candidat == @statut_facture_actuel
      return decision("stale", "Statut identique au statut courant de la facture (observation sans changement)")
    end

    return decision("applied", nil) if transition_autorisee?

    if terminal?
      decision(
        "requires_review",
        "Contradiction : notification \"#{@statut_candidat}\" reçue alors que la facture est déjà " \
        "dans un état terminal (#{@statut_facture_actuel})"
      )
    else
      decision(
        "stale",
        "Régression non reconnue : transition #{@statut_facture_actuel} -> #{@statut_candidat} absente de la table"
      )
    end
  end

  private

  def decision(resultat, motif)
    Decision.new(resultat: resultat, motif: motif)
  end

  # cf. P4 : un message dont l'occurred_at est ANTÉRIEUR à l'occurred_at de
  # la dernière notification déjà APPLIQUÉE sur cette transmission est
  # `stale`, QUELLE QUE SOIT la validité de la transition dans la table.
  def notification_perimee?
    return false if @dernier_occurred_at_applique.blank?
    return false if @occurred_at.blank?

    @occurred_at < @dernier_occurred_at_applique
  end

  def transition_autorisee?
    TRANSITIONS.fetch(@statut_facture_actuel, []).include?(@statut_candidat)
  end

  def terminal?
    TERMINAUX.include?(@statut_facture_actuel)
  end
end
