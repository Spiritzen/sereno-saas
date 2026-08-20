# frozen_string_literal: true

FactoryBot.define do
  # T0 (prompt_claude_code_fix_factory_factures_numero_unique.txt) — séquence
  # FactoryBot monotone et déterministe, jamais un tirage aléatoire dans un
  # espace fini. Avant ce correctif, les traits :emise/:deposee ci-dessous
  # tiraient `rand(1000..9999)` : avec assez de créations dans un même
  # processus de test (ex. 12 factures :emise pour une même organisation dans
  # backend/spec/requests/destinataire/factures_spec.rb), une collision
  # devenait plausible et déclenchait PG::UniqueViolation sur l'index partiel
  # index_factures_unique_numero_by_org (organisation_id, numero), observé
  # une fois en CI puis disparu à la relance sans changement de code —
  # signature classique d'un défaut probabiliste, pas d'une régression
  # fonctionnelle. `generate(:numero_facture_test)` est un compteur GLOBAL au
  # processus : deux appels quelconques, même organisation ou non, ne
  # produisent jamais la même valeur — plus fort que ce que l'index
  # PostgreSQL exige (unique par organisation), donc sans risque de collision
  # résiduel. Format conservé (FAC-AAAA-NNNN) pour rester cohérent avec le
  # format déjà produit par la génération réelle (cf.
  # app/models/numerotation.rb), même si rien ne l'exige strictement ici
  # (numero n'a aucune contrainte de format côté modèle).
  #
  # Déclarée ICI, au niveau racine de FactoryBot.define — PAS à l'intérieur
  # de `factory :facture do` : une sequence déclarée dans un bloc factory
  # devient un attribut implicite de cette factory (FactoryBot essaie alors
  # d'appeler `facture.numero_facture_test =`, qui n'existe pas -> erreur).
  # Constaté à l'exécution pendant ce sprint, corrigé en la remontant ici.
  sequence(:numero_facture_test) do |n|
    "FAC-#{Date.current.year}-#{n.to_s.rjust(4, '0')}"
  end

  factory :facture do
    organisation
    client { association(:client, organisation: organisation) }

    devis_id { nil }
    numero { nil }
    type_document { "facture" }
    statut { "brouillon" }
    date_emission { nil }
    date_echeance { 30.days.from_now.to_date }
    total_ht { 0 }
    total_tva { 0 }
    total_ttc { 0 }
    montant_paye { 0 }
    devise { "EUR" }
    format { "factur_x" }
    mentions { nil }
    conditions_paiement { "Paiement par virement à 30 jours" }
    pdf_url { nil }
    xml_url { nil }
    emise_at { nil }

    trait :avec_ligne do
      after(:create) do |facture|
        create(:ligne_facture, facture: facture, organisation: facture.organisation)
        facture.reload
      end
    end

    trait :emise do
      after(:create) do |facture|
        create(:ligne_facture, facture: facture, organisation: facture.organisation) if facture.lignes_facture.empty?

        facture.reload

        numero = generate(:numero_facture_test)

        facture.update_columns(
          numero: numero,
          statut: "emise",
          date_emission: Date.current,
          emise_at: Time.current,
          pdf_url: "storage/#{Rails.env}/factures/#{facture.id}/facture-#{numero}.pdf",
          xml_url: "storage/#{Rails.env}/factures/#{facture.id}/factur-x-#{numero}.xml",
          updated_at: Time.current
        )
      end
    end

    # Facture déjà émise ET déposée, sans passer par le service
    # d'orchestration : utilisé pour poser le point de départ des tests
    # d'ingestion PA (B3.1a), qui ne testent pas la transmission sortante.
    trait :deposee do
      after(:create) do |facture|
        create(:ligne_facture, facture: facture, organisation: facture.organisation) if facture.lignes_facture.empty?

        facture.reload

        numero = generate(:numero_facture_test)

        facture.update_columns(
          numero: numero,
          statut: "deposee",
          date_emission: Date.current,
          emise_at: Time.current,
          pdf_url: "storage/#{Rails.env}/factures/#{facture.id}/facture-#{numero}.pdf",
          xml_url: "storage/#{Rails.env}/factures/#{facture.id}/factur-x-#{numero}.xml",
          updated_at: Time.current
        )
      end
    end
  end
end
