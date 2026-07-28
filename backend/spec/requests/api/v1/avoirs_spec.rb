# frozen_string_literal: true

require "rails_helper"
require "fileutils"

RSpec.describe "Api::V1::Avoirs", type: :request do
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

    get "/api/v1/avoirs/#{avoir.id}"

    expect(response).to have_http_status(:unauthorized)
  end

  describe "T-ISOLATION (décisif)" do
    let(:organisation_a) { create(:organisation) }
    let(:organisation_b) { create(:organisation) }
    let(:utilisateur_a) { create(:utilisateur, organisation: organisation_a, role: "owner") }
    let(:utilisateur_b) { create(:utilisateur, organisation: organisation_b, role: "owner") }
    let(:client_a) { create(:client, organisation: organisation_a) }
    let(:facture_a) { create(:facture, :emise, organisation: organisation_a, client: client_a) }
    let!(:avoir_a) { create(:avoir, organisation: organisation_a, client: client_a, facture: facture_a) }

    it "refuse à l'organisation B la lecture d'un avoir de l'organisation A (404, jamais 403)" do
      authenticate_as(utilisateur_b, organisation_b)

      get "/api/v1/avoirs/#{avoir_a.id}"

      expect(response).to have_http_status(:not_found)
    end

    it "refuse à l'organisation B l'émission d'un avoir de l'organisation A, sans effet de bord" do
      create(:ligne_avoir, avoir: avoir_a, organisation: organisation_a)
      authenticate_as(utilisateur_b, organisation_b)

      post "/api/v1/avoirs/#{avoir_a.id}/emettre"

      expect(response).to have_http_status(:not_found)
      expect(avoir_a.reload.statut).to eq("brouillon")
    end

    it "ne fait jamais apparaître les avoirs de A dans l'index de B" do
      authenticate_as(utilisateur_b, organisation_b)

      get "/api/v1/avoirs"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.map { |a| a["id"] }).not_to include(avoir_a.id)
    end

    it "refuse de créer un avoir référençant la facture d'une autre organisation (404)" do
      authenticate_as(utilisateur_b, organisation_b)

      post "/api/v1/avoirs", params: { avoir: { facture_id: facture_a.id, motif: "Test" } }

      expect(response).to have_http_status(:not_found)
      expect(EvenementAvoir.count).to eq(0)
    end
  end

  describe "T-CREATE" do
    let(:organisation) { create(:organisation) }
    let(:utilisateur) { create(:utilisateur, organisation: organisation, role: "owner") }
    let(:client) { create(:client, organisation: organisation) }

    before { authenticate_as(utilisateur, organisation) }

    it "crée un avoir brouillon rattaché à une facture émise, avec son événement, dans une seule transaction" do
      facture = create(:facture, :emise, organisation: organisation, client: client)

      post "/api/v1/avoirs", params: { avoir: { facture_id: facture.id, motif: "Erreur de tarif" } }

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["statut"]).to eq("brouillon")
      expect(body["motif"]).to eq("Erreur de tarif")
      expect(body["facture_id"]).to eq(facture.id)
      expect(body["facture_numero"]).to eq(facture.numero)

      avoir = Avoir.find(body["id"])
      expect(avoir.evenements_avoir.count).to eq(1)
      expect(avoir.evenements_avoir.first.statut).to eq("brouillon")
    end

    it "refuse de créer un avoir sur une facture encore en brouillon (règle portée par le modèle, 422)" do
      facture_brouillon = create(:facture, organisation: organisation, client: client)

      post "/api/v1/avoirs", params: { avoir: { facture_id: facture_brouillon.id, motif: "Test" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(EvenementAvoir.count).to eq(0)
      expect(Avoir.count).to eq(0)
    end

    it "refuse sans facture_id" do
      post "/api/v1/avoirs", params: { avoir: { motif: "Test" } }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "T-EMETTRE / T-EMETTRE-KO" do
    let(:organisation) { create(:organisation) }
    let(:utilisateur) { create(:utilisateur, organisation: organisation, role: "owner") }
    let(:client) { create(:client, organisation: organisation) }
    let(:facture) { create(:facture, :emise, organisation: organisation, client: client) }
    let(:avoir) { create(:avoir, organisation: organisation, client: client, facture: facture) }

    before { authenticate_as(utilisateur, organisation) }

    after { FileUtils.rm_rf(Rails.root.join("storage", Rails.env, "avoirs", avoir.id.to_s)) }

    it "T-EMETTRE : émet l'avoir, attribue un numéro AV, crée l'événement d'émission" do
      create(:ligne_avoir, avoir: avoir, organisation: organisation, quantite: 2, prix_unitaire_ht: 100, taux_tva: 20)

      post "/api/v1/avoirs/#{avoir.id}/emettre"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["statut"]).to eq("emise")
      expect(body["numero"]).to match(/\AAV-\d{4}-\d{4}\z/)

      avoir.reload
      expect(avoir.evenements_avoir.count).to eq(1)
      expect(avoir.evenements_avoir.first.statut).to eq("emise")
    end

    it "T-EMETTRE-KO (décisif) : un avoir sans ligne est refusé (422, pas 403), rien n'est émis" do
      post "/api/v1/avoirs/#{avoir.id}/emettre"

      expect(response).to have_http_status(:unprocessable_entity)
      body = JSON.parse(response.body)
      expect(body["details"].join(" ")).to include("L'avoir doit contenir au moins une ligne")

      avoir.reload
      expect(avoir.statut).to eq("brouillon")
      expect(avoir.evenements_avoir.count).to eq(0)
    end
  end

  describe "T-INDEX-FILTRE" do
    let(:organisation) { create(:organisation) }
    let(:utilisateur) { create(:utilisateur, organisation: organisation, role: "owner") }
    let(:client) { create(:client, organisation: organisation) }

    before { authenticate_as(utilisateur, organisation) }

    it "GET /avoirs?facture_id=X ne renvoie que les avoirs de cette facture" do
      facture_1 = create(:facture, :emise, organisation: organisation, client: client)
      facture_2 = create(:facture, :emise, organisation: organisation, client: client)
      avoir_1 = create(:avoir, organisation: organisation, client: client, facture: facture_1)
      avoir_2 = create(:avoir, organisation: organisation, client: client, facture: facture_2)

      get "/api/v1/avoirs", params: { facture_id: facture_1.id }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.map { |a| a["id"] }).to contain_exactly(avoir_1.id)
      expect(body.map { |a| a["id"] }).not_to include(avoir_2.id)
    end
  end
end
