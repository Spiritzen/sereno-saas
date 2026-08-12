# frozen_string_literal: true

# Relances v1a — orchestration de l'acte manuel "Relancer" : construit la
# Relance, tente l'envoi du mail, puis journalise en UNE seule écriture
# (append-only, cf. Relance#empecher_update). Aucune mutation de Facture —
# reste_a_payer/relancable? restent entièrement dérivés, comme pour les
# paiements (cf. PaiementService, même discipline).
class RelanceService
  def initialize(organisation:, utilisateur:)
    @organisation = organisation
    @utilisateur = utilisateur
  end

  def envoyer!(facture:)
    relance = construire(facture)

    # Validé AVANT toute tentative d'envoi : si la facture n'est pas
    # relancable (ou destinataire/objet invalides), on ne construit ni
    # n'envoie de mail pour rien. Fait remonter la même
    # ActiveRecord::RecordInvalid que le contrôleur sait déjà gérer
    # (cf. Api::V1::PaiementsController).
    raise ActiveRecord::RecordInvalid.new(relance) unless relance.valid?

    mode_livraison = mode_livraison_reel

    begin
      RelanceMailer.rappel(relance).deliver_now
      relance.assign_attributes(
        statut: "envoyee",
        envoyee_at: Time.current,
        mode_livraison: mode_livraison
      )
    rescue StandardError
      # Honnêteté produit (§2.6) : un échec de livraison est JOURNALISÉ tel
      # quel, jamais maquillé en succès. envoyee_at reste nil (aucune
      # livraison n'a eu lieu).
      relance.assign_attributes(statut: "echec", mode_livraison: mode_livraison)
    end

    relance.save!
    relance
  end

  private

  def construire(facture)
    @organisation.relances.new(
      facture: facture,
      utilisateur: @utilisateur,
      canal: "email",
      niveau: 1,
      # Acte manuel (v1a) : origine "manuel", pas de date_planifiee — c'est
      # un envoi immédiat, pas une échéance de planificateur (exécution du
      # 12/08/2026 ; date_planifiee reste réservée à origine "planifie").
      origine: "manuel",
      date_planifiee: nil,
      destinataire_email: facture.client&.email,
      objet: "Rappel de paiement — facture #{facture.numero}"
    )
  end

  # VÉRITÉ du canal de livraison réellement configuré — jamais une
  # constante figée par environnement. Reflète tel quel
  # config.action_mailer.delivery_method ("letter_opener" en dev, "test" en
  # test — les deliveries vont dans un tableau mémoire, pas au réseau —,
  # "smtp" en prod) : si Sébastien change ce réglage un jour, la Relance
  # enregistrée suit sans qu'on ait à toucher ce service.
  def mode_livraison_reel
    ActionMailer::Base.delivery_method.to_s
  end
end
