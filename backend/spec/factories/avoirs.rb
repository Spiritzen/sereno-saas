# frozen_string_literal: true

FactoryBot.define do
  factory :avoir do
    organisation
    client { association(:client, organisation: organisation) }
    facture { association(:facture, :emise, organisation: organisation, client: client) }

    motif { "Erreur de facturation" }
    statut { "brouillon" }

    # V1.2c — même patron que Facture :emise/:deposee (update_columns direct,
    # sans passer par AvoirEmissionService) : point de départ rapide pour les
    # tests de transmission/ingestion, qui ne testent pas la génération
    # elle-même (déjà couverte en V1.2a).
    trait :emise do
      after(:create) do |avoir|
        create(:ligne_avoir, avoir: avoir, organisation: avoir.organisation) if avoir.lignes_avoir.empty?
        avoir.reload

        numero = "AV-#{Date.current.year}-#{format('%04d', rand(1000..9999))}"

        avoir.update_columns(
          numero: numero,
          statut: "emise",
          date_emission: Date.current,
          emis_at: Time.current,
          pdf_url: "storage/#{Rails.env}/avoirs/#{avoir.id}/avoir-#{numero}.pdf",
          xml_url: "storage/#{Rails.env}/avoirs/#{avoir.id}/avoir-#{numero}.xml",
          updated_at: Time.current
        )
      end
    end

    trait :deposee do
      after(:create) do |avoir|
        create(:ligne_avoir, avoir: avoir, organisation: avoir.organisation) if avoir.lignes_avoir.empty?
        avoir.reload

        numero = "AV-#{Date.current.year}-#{format('%04d', rand(1000..9999))}"

        avoir.update_columns(
          numero: numero,
          statut: "deposee",
          date_emission: Date.current,
          emis_at: Time.current,
          pdf_url: "storage/#{Rails.env}/avoirs/#{avoir.id}/avoir-#{numero}.pdf",
          xml_url: "storage/#{Rails.env}/avoirs/#{avoir.id}/avoir-#{numero}.xml",
          updated_at: Time.current
        )
      end
    end
  end
end
