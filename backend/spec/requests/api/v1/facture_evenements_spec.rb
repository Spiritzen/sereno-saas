# frozen_string_literal: true

require "rails_helper"
require "fileutils"

RSpec.describe "Api::V1::FactureEvenements — verrouillage 97", type: :request do
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

  describe "A. isolation tenant stricte" do
    let(:organisation_a) { create(:organisation) }
    let(:organisation_b) { create(:organisation) }
    let(:utilisateur_a) { create(:utilisateur, organisation: organisation_a, role: "owner") }
    let(:utilisateur_b) { create(:utilisateur, organisation: organisation_b, role: "owner") }
    let(:client_a) { create(:client, organisation: organisation_a, statut: "actif") }

    # La facture A est créée via le vrai flux HTTP (et non via la factory en
    # accès direct) afin qu'elle porte réellement son événement "brouillon",
    # exactement comme en production.
    def creer_facture_a
      authenticate_as(utilisateur_a, organisation_a)

      post "/api/v1/factures", params: { facture: { client_id: client_a.id } }

      JSON.parse(response.body)["id"]
    end

    it "refuse à l'utilisateur B la lecture des événements d'une facture de l'organisation A" do
      facture_a_id = creer_facture_a

      authenticate_as(utilisateur_b, organisation_b)

      get "/api/v1/factures/#{facture_a_id}/evenements"

      expect(response).to have_http_status(:not_found)
    end

    it "ne laisse fuiter aucun événement de l'organisation A dans la réponse à l'organisation B" do
      facture_a_id = creer_facture_a

      authenticate_as(utilisateur_b, organisation_b)

      get "/api/v1/factures/#{facture_a_id}/evenements"

      expect(response.body).not_to match(/brouillon|facture_creee/)
    end

    it "autorise l'utilisateur A à lire les événements de sa propre facture" do
      facture_a_id = creer_facture_a

      get "/api/v1/factures/#{facture_a_id}/evenements"

      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)

      expect(body).not_to be_empty
      expect(body.first["statut"]).to eq("brouillon")
    end
  end

  describe "C. authentification requise" do
    it "renvoie 401 sans authentification" do
      facture = create(:facture)

      get "/api/v1/factures/#{facture.id}/evenements"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "D. lecture seule stricte" do
    let(:organisation) { create(:organisation) }
    let(:utilisateur) { create(:utilisateur, organisation: organisation, role: "owner") }
    let(:facture) { create(:facture, organisation: organisation) }

    before do
      authenticate_as(utilisateur, organisation)
    end

    it "ne route aucune action de création sur /evenements" do
      post "/api/v1/factures/#{facture.id}/evenements", params: {
        evenement_facture: { statut: "emise" }
      }

      expect(response).to have_http_status(:not_found)
    end

    it "ne route aucune action de modification sur /evenements" do
      patch "/api/v1/factures/#{facture.id}/evenements/#{SecureRandom.uuid}"

      expect(response).to have_http_status(:not_found)
    end

    it "ne route aucune action de suppression sur /evenements" do
      delete "/api/v1/factures/#{facture.id}/evenements/#{SecureRandom.uuid}"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "E. sérialisation sans fuite de données sensibles" do
    let(:organisation) { create(:organisation) }
    let(:utilisateur) do
      create(:utilisateur, organisation: organisation, role: "owner", prenom: "Ada", nom: "Lovelace")
    end
    let(:client) { create(:client, organisation: organisation, statut: "actif") }

    before do
      authenticate_as(utilisateur, organisation)
    end

    it "n'expose ni l'email de l'acteur, ni pdf_url/xml_url, sur un événement d'émission réel" do
      facture = create(:facture, :avec_ligne, organisation: organisation, client: client)

      post "/api/v1/factures/#{facture.id}/emettre"
      expect(response).to have_http_status(:ok)

      get "/api/v1/factures/#{facture.id}/evenements"
      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      evenement_emise = body.find { |evenement| evenement["statut"] == "emise" }

      expect(evenement_emise).not_to be_nil
      expect(evenement_emise["details"]).not_to have_key("pdf_url")
      expect(evenement_emise["details"]).not_to have_key("xml_url")
      expect(evenement_emise["actor"]).to eq(
        "id" => utilisateur.id,
        "display_name" => "Ada Lovelace"
      )

      expect(response.body).not_to include(utilisateur.email)
      expect(response.body).not_to include(".pdf")
      expect(response.body).not_to include(".xml")
    ensure
      FileUtils.rm_rf(Rails.root.join("storage", Rails.env, "factures", facture&.id.to_s)) if facture
    end
  end

  describe "G. boucle complète création → lecture (cohérence V1.1-A)" do
    let(:organisation) { create(:organisation) }
    let(:utilisateur) { create(:utilisateur, organisation: organisation, role: "owner") }
    let(:client) { create(:client, organisation: organisation, statut: "actif") }

    before do
      authenticate_as(utilisateur, organisation)
    end

    it "rend immédiatement visible, via l'API de lecture, l'événement brouillon créé à la création d'une facture" do
      post "/api/v1/factures", params: { facture: { client_id: client.id } }
      expect(response).to have_http_status(:created)

      facture_id = JSON.parse(response.body)["id"]

      get "/api/v1/factures/#{facture_id}/evenements"
      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)

      expect(body.length).to eq(1)
      expect(body.first["statut"]).to eq("brouillon")
      expect(body.first["actor"]).to eq(
        "id" => utilisateur.id,
        "display_name" => "#{utilisateur.prenom} #{utilisateur.nom}"
      )
    end
  end
end
