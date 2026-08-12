# frozen_string_literal: true

FactoryBot.define do
  factory :relance do
    organisation
    utilisateur { association(:utilisateur, organisation: organisation) }
    # Facture relancable par défaut : émise, échéance dépassée, non payée
    # (aucun paiement confirmé -> reste_a_payer = total_ttc > 0, cf.
    # PaiementSyntheseService). Voir Facture#relancable?.
    facture { association(:facture, :emise, organisation: organisation, date_echeance: 1.day.ago) }

    canal { "email" }
    niveau { 1 }
    # Défaut MANUEL (v1a, exécution du 12/08/2026) : reflète tel quel ce que
    # RelanceService#construire produit réellement — pas de date_planifiee.
    origine { "manuel" }
    date_planifiee { nil }
    statut { "envoyee" }
    envoyee_at { Time.current }
    destinataire_email { "client@test.fr" }
    objet { "Rappel de paiement" }
    mode_livraison { "letter_opener" }

    # v1b (futur planificateur) : origine "planifie", date_planifiee requise
    # (cf. Relance#origine_planifiee? et sa validation conditionnelle). Pas
    # encore de flux réel de création — trait prêt pour les tests du futur
    # planificateur, jamais exercé par le code applicatif aujourd'hui.
    trait :planifiee do
      origine { "planifie" }
      date_planifiee { 3.days.from_now.to_date }
      statut { "planifiee" }
      envoyee_at { nil }
      mode_livraison { nil }
    end
  end
end
