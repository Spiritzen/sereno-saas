# frozen_string_literal: true

# Relances v1a (manuel) + v1b (planificateur, scan-and-send) — orchestration
# de l'envoi d'UN rappel : construit la Relance, tente l'envoi du mail, puis
# journalise en UNE seule écriture (append-only, cf. Relance#empecher_update).
# Aucune mutation de Facture — reste_a_payer/relancable? restent entièrement
# dérivés, comme pour les paiements (cf. PaiementService, même discipline).
#
# v1b (13/08/2026) : `envoyer!` accepte désormais origine/niveau/date_planifiee
# avec des DÉFAUTS qui laissent le chemin MANUEL v1a strictement inchangé
# (origine "manuel", niveau 1, date_planifiee nil — exactement ce que
# Api::V1::RelancesController appelle, sans rien connaître de v1b).
# `utilisateur` devient optionnel : une relance AUTO n'a pas d'acteur humain
# (RelanceEnvoiJob ne passe pas d'utilisateur).
class RelanceService
  def initialize(organisation:, utilisateur: nil)
    @organisation = organisation
    @utilisateur = utilisateur
  end

  def envoyer!(facture:, origine: "manuel", niveau: 1, date_planifiee: nil)
    relance = construire(facture, origine: origine, niveau: niveau, date_planifiee: date_planifiee)

    # Validé AVANT toute tentative d'envoi : si la facture n'est pas
    # relancable (ou destinataire/objet invalides), on ne construit ni
    # n'envoie de mail pour rien. Fait remonter la même
    # ActiveRecord::RecordInvalid que le contrôleur sait déjà gérer
    # (cf. Api::V1::PaiementsController).
    raise ActiveRecord::RecordInvalid.new(relance) unless relance.valid?

    mode_livraison = mode_livraison_reel(origine)

    begin
      RelanceMailer.rappel(relance, delivery_method: delivery_method_override(origine)).deliver_now
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

  def construire(facture, origine:, niveau:, date_planifiee:)
    @organisation.relances.new(
      facture: facture,
      utilisateur: @utilisateur,
      canal: "email",
      niveau: niveau,
      origine: origine,
      date_planifiee: date_planifiee,
      destinataire_email: facture.client&.email,
      objet: objet_pour(facture, niveau)
    )
  end

  # Niveau 1 (manuel v1a ou 1er palier auto) : wording INCHANGÉ depuis v1a.
  # Niveau 2/3 (auto uniquement, le manuel reste toujours niveau 1) : le
  # sujet reflète le palier — cf. §6 execution_relances_v1b ("sans en faire
  # trop" : un seul mot ajouté, pas un ton différent dans l'objet).
  def objet_pour(facture, niveau)
    base = "Rappel de paiement — facture #{facture.numero}"
    return base if niveau <= 1

    "Rappel de paiement (relance #{niveau}) — facture #{facture.numero}"
  end

  # VÉRITÉ du canal de livraison RÉELLEMENT utilisé pour CET envoi. Reflète
  # la config ActionMailer par défaut ("letter_opener" en dev, "test" en
  # test, "smtp" en prod), SAUF le cas précis couvert par
  # #delivery_method_override ci-dessous (auto + letter_opener) où c'est
  # "file" qui est réellement utilisé — jamais un mensonge, toujours ce qui
  # s'est réellement passé.
  def mode_livraison_reel(origine)
    override = delivery_method_override(origine)
    return override.to_s if override

    ActionMailer::Base.delivery_method.to_s
  end

  # v1b (§6) : un job de fond (RelanceEnvoiJob) ne doit jamais tenter
  # d'ouvrir un onglet navigateur — c'est pourtant ce que ferait
  # letter_opener (Launchy.open) s'il était laissé tel quel. Bascule donc
  # vers :file (Mail::FileDelivery, natif Rails : écrit un .eml sur disque,
  # aucun navigateur) UNIQUEMENT quand origine est "planifie" ET que la
  # config réelle est :letter_opener. Override PAR MESSAGE (mail(...,
  # delivery_method:) — cf. RelanceMailer), jamais une mutation globale de
  # ActionMailer::Base.delivery_method : Solid Queue traite plusieurs jobs
  # en parallèle (config/queue.yml, threads: 3) — muter un class_attribute
  # partagé serait une course entre threads.
  # Le clic MANUEL (v1a) n'est jamais concerné : origine y est toujours
  # "manuel", donc toujours nil ici — il garde tel quel le comportement
  # voulu (l'onglet letter_opener).
  # En prod (smtp) comme en test (:test), rien ne change : override nil.
  def delivery_method_override(origine)
    return nil unless origine == "planifie"
    return nil unless ActionMailer::Base.delivery_method.to_s == "letter_opener"

    :file
  end
end
