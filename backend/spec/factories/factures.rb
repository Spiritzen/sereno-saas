# frozen_string_literal: true

FactoryBot.define do
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

        numero = "FAC-#{Date.current.year}-#{format('%04d', rand(1000..9999))}"

        facture.update_columns(
          numero: numero,
          statut: "emise",
          date_emission: Date.current,
          emise_at: Time.current,
          pdf_url: "storage/factures/#{facture.id}/facture-#{numero}.pdf",
          xml_url: "storage/factures/#{facture.id}/factur-x-#{numero}.xml",
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

        numero = "FAC-#{Date.current.year}-#{format('%04d', rand(1000..9999))}"

        facture.update_columns(
          numero: numero,
          statut: "deposee",
          date_emission: Date.current,
          emise_at: Time.current,
          pdf_url: "storage/factures/#{facture.id}/facture-#{numero}.pdf",
          xml_url: "storage/factures/#{facture.id}/factur-x-#{numero}.xml",
          updated_at: Time.current
        )
      end
    end
  end
end
