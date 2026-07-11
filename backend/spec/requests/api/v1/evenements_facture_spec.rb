# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::EvenementsFacture", type: :request do
  def authenticate_as(utilisateur, organisation)
    allow_any_instance_of(Api::V1::BaseController)
      .to receive(:authenticate_request!) do
        Current.organisation = organisation
        Current.utilisateur = utilisateur
        Current.session = nil
      end
  end

  after do
    Current.reset
  end

  it "refuse l'accès sans authentification" do
    facture = create(:facture)

    get "/api/v1/factures/#{facture.id}/evenements"

    expect(response).to have_http_status(:unauthorized)
  end

  describe "isolation tenant" do
    let(:organisation_a) { create(:organisation) }
    let(:organisation_b) { create(:organisation) }
    let(:utilisateur_a) { create(:utilisateur, organisation: organisation_a) }

    before do
      authenticate_as(utilisateur_a, organisation_a)
    end

    it "empêche de lister les événements d'une facture d'une autre organisation" do
      facture_b = create(:facture, organisation: organisation_b)

      get "/api/v1/factures/#{facture_b.id}/evenements"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "liste des événements d'une facture accessible" do
    let(:organisation) { create(:organisation) }
    let(:utilisateur) { create(:utilisateur, organisation: organisation, nom: "Cantrelle", prenom: "Sébastien") }

    before do
      authenticate_as(utilisateur, organisation)
    end

    it "retourne une liste vide pour une facture sans événement" do
      facture = create(:facture, organisation: organisation)

      get "/api/v1/factures/#{facture.id}/evenements"

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq([])
    end

    it "retourne les événements dans l'ordre chronologique avec un contrat filtré" do
      facture = create(:facture, organisation: organisation)

      premier = EvenementFacture.create!(
        organisation: organisation,
        facture: facture,
        utilisateur: utilisateur,
        statut: "brouillon",
        source: "interne",
        payload: { action: "facture_creee" }
      )

      second = EvenementFacture.create!(
        organisation: organisation,
        facture: facture,
        utilisateur: utilisateur,
        statut: "emise",
        source: "interne",
        payload: {
          action: "emission_facture",
          numero: "FAC-2026-0099",
          date_emission: "2026-07-11",
          emise_at: "2026-07-11T10:00:00Z",
          pdf_url: "storage/factures/secret.pdf",
          xml_url: "storage/factures/secret.xml"
        }
      )

      get "/api/v1/factures/#{facture.id}/evenements"

      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)

      expect(body.map { |e| e["id"] }).to eq([ premier.id, second.id ])
      expect(body.map { |e| e["statut"] }).to eq(%w[brouillon emise])

      expect(body[0]["actor"]).to eq(
        "id" => utilisateur.id,
        "display_name" => "Sébastien Cantrelle"
      )
      expect(body[0]["details"]).to eq("action" => "facture_creee")

      expect(body[1]["details"]).to eq(
        "action" => "emission_facture",
        "numero" => "FAC-2026-0099",
        "date_emission" => "2026-07-11",
        "emise_at" => "2026-07-11T10:00:00Z"
      )
      expect(body[1]["details"]).not_to have_key("pdf_url")
      expect(body[1]["details"]).not_to have_key("xml_url")
      expect(response.body).not_to include(utilisateur.email)
    end

    it "n'expose aucune action d'écriture" do
      facture = create(:facture, organisation: organisation)

      post "/api/v1/factures/#{facture.id}/evenements", params: {}

      expect(response).to have_http_status(:not_found)
    end
  end
end
