# frozen_string_literal: true

require "rails_helper"
require "fileutils"

RSpec.describe "Api::V1::EvenementsAvoir — gabarit facture_evenements_spec", type: :request do
  def authenticate_as(utilisateur, organisation)
    allow_any_instance_of(Api::V1::BaseController)
      .to receive(:authenticate_request!) do
        Current.organisation = organisation
        Current.utilisateur = utilisateur
        Current.session = nil
      end
  end

  after { Current.reset }

  it "refuse l'accès sans authentification" do
    avoir = create(:avoir)

    get "/api/v1/avoirs/#{avoir.id}/evenements"

    expect(response).to have_http_status(:unauthorized)
  end

  describe "A. isolation tenant stricte" do
    let(:organisation_a) { create(:organisation) }
    let(:organisation_b) { create(:organisation) }
    let(:utilisateur_a) { create(:utilisateur, organisation: organisation_a, role: "owner") }
    let(:utilisateur_b) { create(:utilisateur, organisation: organisation_b, role: "owner") }
    let(:client_a) { create(:client, organisation: organisation_a) }

    # L'avoir A est créé via le vrai flux HTTP afin qu'il porte réellement
    # son événement "brouillon", comme en production (même discipline que
    # facture_evenements_spec.rb).
    def creer_avoir_a
      authenticate_as(utilisateur_a, organisation_a)
      facture = create(:facture, :emise, organisation: organisation_a, client: client_a)

      post "/api/v1/avoirs", params: { avoir: { facture_id: facture.id, motif: "Erreur de tarif" } }

      JSON.parse(response.body)["id"]
    end

    it "refuse à l'organisation B la lecture des événements d'un avoir de A (404, jamais 403)" do
      avoir_a_id = creer_avoir_a

      authenticate_as(utilisateur_b, organisation_b)
      get "/api/v1/avoirs/#{avoir_a_id}/evenements"

      expect(response).to have_http_status(:not_found)
    end

    it "ne laisse fuiter aucun événement de A dans la réponse à B" do
      avoir_a_id = creer_avoir_a

      authenticate_as(utilisateur_b, organisation_b)
      get "/api/v1/avoirs/#{avoir_a_id}/evenements"

      expect(response.body).not_to match(/brouillon|avoir_cree/)
    end

    it "autorise A à lire les événements de son propre avoir" do
      avoir_a_id = creer_avoir_a

      get "/api/v1/avoirs/#{avoir_a_id}/evenements"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)

      expect(body).not_to be_empty
      expect(body.first["statut"]).to eq("brouillon")
    end
  end

  describe "D. lecture seule stricte (T-APPEND-ONLY, décisif)" do
    let(:organisation) { create(:organisation) }
    let(:utilisateur) { create(:utilisateur, organisation: organisation, role: "owner") }
    let(:avoir) { create(:avoir, organisation: organisation) }

    before { authenticate_as(utilisateur, organisation) }

    it "ne route aucune action de création sur /evenements" do
      post "/api/v1/avoirs/#{avoir.id}/evenements", params: {
        evenement_avoir: { statut: "emise" }
      }

      expect(response).to have_http_status(:not_found)
    end

    it "ne route aucune action de modification sur /evenements" do
      patch "/api/v1/avoirs/#{avoir.id}/evenements/#{SecureRandom.uuid}"

      expect(response).to have_http_status(:not_found)
    end

    it "ne route aucune action de suppression sur /evenements" do
      delete "/api/v1/avoirs/#{avoir.id}/evenements/#{SecureRandom.uuid}"

      expect(response).to have_http_status(:not_found)
    end

    it "un update direct d'un EvenementAvoir lève (append-only, modèle)" do
      evenement = create(:evenement_avoir, avoir: avoir, organisation: organisation)

      expect { evenement.update!(statut: "emise") }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "un destroy direct d'un EvenementAvoir lève (append-only, modèle)" do
      evenement = create(:evenement_avoir, avoir: avoir, organisation: organisation)

      expect { evenement.destroy! }.to raise_error(ActiveRecord::RecordNotDestroyed)
    end
  end

  describe "E. sérialisation sans fuite de données sensibles (T-NON-FUITE, décisif)" do
    let(:organisation) { create(:organisation) }
    let(:utilisateur) do
      create(:utilisateur, organisation: organisation, role: "owner", prenom: "Ada", nom: "Lovelace")
    end
    let(:client) { create(:client, organisation: organisation) }

    before { authenticate_as(utilisateur, organisation) }

    it "n'expose ni l'email de l'acteur, ni pdf_url/xml_url, sur un événement d'émission réel" do
      facture = create(:facture, :emise, organisation: organisation, client: client)
      avoir = create(:avoir, organisation: organisation, client: client, facture: facture)
      create(:ligne_avoir, avoir: avoir, organisation: organisation, quantite: 2, prix_unitaire_ht: 100, taux_tva: 20)

      post "/api/v1/avoirs/#{avoir.id}/emettre"
      expect(response).to have_http_status(:ok)

      get "/api/v1/avoirs/#{avoir.id}/evenements"
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
      FileUtils.rm_rf(Rails.root.join("storage", "factures", avoir&.id.to_s)) if avoir
    end
  end

  describe "G. boucle complète création → émission → lecture (T-BOUCLE)" do
    let(:organisation) { create(:organisation) }
    let(:utilisateur) { create(:utilisateur, organisation: organisation, role: "owner") }
    let(:client) { create(:client, organisation: organisation) }

    before { authenticate_as(utilisateur, organisation) }

    it "les deux événements apparaissent dans l'ordre, via GET evenements" do
      facture = create(:facture, :emise, organisation: organisation, client: client)

      post "/api/v1/avoirs", params: { avoir: { facture_id: facture.id, motif: "Erreur" } }
      expect(response).to have_http_status(:created)
      avoir_id = JSON.parse(response.body)["id"]

      create(:ligne_avoir, avoir: Avoir.find(avoir_id), organisation: organisation,
                           quantite: 1, prix_unitaire_ht: 50, taux_tva: 20)

      post "/api/v1/avoirs/#{avoir_id}/emettre"
      expect(response).to have_http_status(:ok)

      get "/api/v1/avoirs/#{avoir_id}/evenements"
      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body.length).to eq(2)
      expect(body.map { |evenement| evenement["statut"] }).to eq(%w[brouillon emise])
    ensure
      FileUtils.rm_rf(Rails.root.join("storage", "factures", avoir_id.to_s)) if avoir_id
    end
  end
end
