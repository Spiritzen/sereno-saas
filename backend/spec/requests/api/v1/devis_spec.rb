# frozen_string_literal: true

require "rails_helper"
require "fileutils"

RSpec.describe "Api::V1::Devis", type: :request do
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
    devis = create(:devis)

    get "/api/v1/devis/#{devis.id}"

    expect(response).to have_http_status(:unauthorized)
  end

  describe "T-ISOLATION (décisif)" do
    let(:organisation_a) { create(:organisation) }
    let(:organisation_b) { create(:organisation) }
    let(:utilisateur_a) { create(:utilisateur, organisation: organisation_a, role: "owner") }
    let(:utilisateur_b) { create(:utilisateur, organisation: organisation_b, role: "owner") }
    let(:client_a) { create(:client, organisation: organisation_a) }
    let!(:devis_a) { create(:devis, :avec_ligne, organisation: organisation_a, client: client_a) }

    it "refuse à l'organisation B la lecture d'un devis de l'organisation A (404, jamais 403)" do
      authenticate_as(utilisateur_b, organisation_b)

      get "/api/v1/devis/#{devis_a.id}"

      expect(response).to have_http_status(:not_found)
    end

    it "refuse à l'organisation B la conversion d'un devis de l'organisation A (404), sans effet de bord" do
      authenticate_as(utilisateur_b, organisation_b)

      post "/api/v1/devis/#{devis_a.id}/convertir"

      expect(response).to have_http_status(:not_found)
      expect(Facture.where(devis_id: devis_a.id).count).to eq(0)
    end

    it "refuse à l'organisation B d'envoyer un devis de l'organisation A (404)" do
      authenticate_as(utilisateur_b, organisation_b)

      post "/api/v1/devis/#{devis_a.id}/envoyer"

      expect(response).to have_http_status(:not_found)
      expect(devis_a.reload.statut).to eq("brouillon")
    end

    it "ne fait jamais apparaître les devis de A dans l'index de B" do
      authenticate_as(utilisateur_b, organisation_b)

      get "/api/v1/devis"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.map { |d| d["id"] }).not_to include(devis_a.id)
    end
  end

  describe "rôle non autorisé (403)" do
    let(:organisation) { create(:organisation) }
    let(:membre) { create(:utilisateur, organisation: organisation, role: "membre") }
    let(:client) { create(:client, organisation: organisation) }

    before { authenticate_as(membre, organisation) }

    it "refuse à un membre la création d'un devis (403, pas 422/500)" do
      post "/api/v1/devis", params: { devis: { client_id: client.id, objet: "Test" } }

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "T-CREATE / T-UPDATE / T-DESTROY" do
    let(:organisation) { create(:organisation) }
    let(:utilisateur) { create(:utilisateur, organisation: organisation, role: "owner") }
    let(:client) { create(:client, organisation: organisation) }

    before { authenticate_as(utilisateur, organisation) }

    it "crée un devis brouillon SANS événement (choix assumé, cf. commentaire du contrôleur)" do
      post "/api/v1/devis", params: { devis: { client_id: client.id, objet: "Refonte du site" } }

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["statut"]).to eq("brouillon")
      expect(body["numero"]).to be_nil
      expect(body["objet"]).to eq("Refonte du site")

      expect(EvenementDevis.where(devis_id: body["id"]).count).to eq(0)
    end

    it "refuse sans client_id" do
      post "/api/v1/devis", params: { devis: { objet: "Test" } }

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "autorise la modification d'un devis brouillon" do
      devis = create(:devis, organisation: organisation, client: client)

      patch "/api/v1/devis/#{devis.id}", params: { devis: { objet: "Objet modifié" } }

      expect(response).to have_http_status(:ok)
      expect(devis.reload.objet).to eq("Objet modifié")
    end

    it "refuse la modification d'un devis envoyé (422, pas 403 — règle portée par le modèle)" do
      devis = create(:devis, :avec_ligne, organisation: organisation, client: client)
      DevisStatutService.new(devis: devis, utilisateur: utilisateur).envoyer!

      patch "/api/v1/devis/#{devis.id}", params: { devis: { objet: "Tentative interdite" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(devis.reload.objet).not_to eq("Tentative interdite")
    end

    it "autorise la suppression d'un devis brouillon" do
      devis = create(:devis, :avec_ligne, organisation: organisation, client: client)

      delete "/api/v1/devis/#{devis.id}"

      expect(response).to have_http_status(:no_content)
      expect(Devis.exists?(devis.id)).to be(false)
    end

    it "refuse la suppression d'un devis envoyé (422, pas 403)" do
      devis = create(:devis, :avec_ligne, organisation: organisation, client: client)
      DevisStatutService.new(devis: devis, utilisateur: utilisateur).envoyer!

      delete "/api/v1/devis/#{devis.id}"

      expect(response).to have_http_status(:unprocessable_entity)
      expect(Devis.exists?(devis.id)).to be(true)
    end
  end

  describe "T-TRANSITIONS" do
    let(:organisation) { create(:organisation) }
    let(:utilisateur) { create(:utilisateur, organisation: organisation, role: "owner") }
    let(:client) { create(:client, organisation: organisation) }

    before { authenticate_as(utilisateur, organisation) }

    it "envoie un devis brouillon : statut envoye + numéro DEV attribué" do
      devis = create(:devis, :avec_ligne, organisation: organisation, client: client)

      post "/api/v1/devis/#{devis.id}/envoyer"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["statut"]).to eq("envoye")
      expect(body["numero"]).to match(/\ADEV-#{Date.current.year}-\d{4}\z/)
    end

    it "refuse un saut d'étape (brouillon -> accepte directement), 422 pas 403" do
      devis = create(:devis, :avec_ligne, organisation: organisation, client: client)

      post "/api/v1/devis/#{devis.id}/accepter"

      expect(response).to have_http_status(:unprocessable_entity)
      expect(devis.reload.statut).to eq("brouillon")
    end

    it "accepte un devis envoyé" do
      devis = create(:devis, :avec_ligne, organisation: organisation, client: client)
      post "/api/v1/devis/#{devis.id}/envoyer"

      post "/api/v1/devis/#{devis.id}/accepter"

      expect(response).to have_http_status(:ok)
      expect(devis.reload.statut).to eq("accepte")
    end

    it "refuse toute transition après un statut terminal (refuse -> envoyer de nouveau)" do
      devis = create(:devis, :avec_ligne, organisation: organisation, client: client)
      post "/api/v1/devis/#{devis.id}/envoyer"
      post "/api/v1/devis/#{devis.id}/refuser"

      post "/api/v1/devis/#{devis.id}/envoyer"

      expect(response).to have_http_status(:unprocessable_entity)
      expect(devis.reload.statut).to eq("refuse")
    end
  end

  describe "T-CONVERTIR" do
    let(:organisation) { create(:organisation) }
    let(:utilisateur) { create(:utilisateur, organisation: organisation, role: "owner") }
    let(:client) { create(:client, organisation: organisation) }

    before { authenticate_as(utilisateur, organisation) }

    def accepter_devis(devis)
      post "/api/v1/devis/#{devis.id}/envoyer"
      post "/api/v1/devis/#{devis.id}/accepter"
      devis.reload
    end

    it "convertit un devis accepté et renvoie la FACTURE créée (FactureBlueprint), émise" do
      devis = create(:devis, :avec_ligne, organisation: organisation, client: client)
      accepter_devis(devis)

      post "/api/v1/devis/#{devis.id}/convertir"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["statut"]).to eq("emise")
      expect(body["numero"]).to match(/\AFAC-#{Date.current.year}-\d{4}\z/)
      expect(body["devis_id"]).to eq(devis.id)
    ensure
      facture_id = defined?(body) ? body&.dig("id") : nil
      FileUtils.rm_rf(Rails.root.join("storage", Rails.env, "factures", facture_id.to_s)) if facture_id
    end

    it "refuse de convertir un devis non accepté (422, pas 403)" do
      devis = create(:devis, :avec_ligne, organisation: organisation, client: client)

      post "/api/v1/devis/#{devis.id}/convertir"

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to match(/doit être accepté/)
    end

    it "refuse une seconde conversion du même devis (idempotence, 422 avec la référence existante)" do
      devis = create(:devis, :avec_ligne, organisation: organisation, client: client)
      accepter_devis(devis)

      post "/api/v1/devis/#{devis.id}/convertir"
      premiere_facture_id = JSON.parse(response.body)["id"]

      post "/api/v1/devis/#{devis.id}/convertir"

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to match(/déjà converti/)
      expect(Facture.where(devis_id: devis.id).count).to eq(1)
    ensure
      FileUtils.rm_rf(Rails.root.join("storage", Rails.env, "factures", premiere_facture_id.to_s)) if defined?(premiere_facture_id) && premiere_facture_id
    end
  end

  describe "T-BLUEPRINT (décisif) : sérialisation sans fuite" do
    let(:organisation) { create(:organisation) }
    let(:utilisateur) do
      create(:utilisateur, organisation: organisation, role: "owner", prenom: "Ada", nom: "Lovelace", email: "ada@sereno-secret.fr")
    end
    let(:client) { create(:client, organisation: organisation) }

    before { authenticate_as(utilisateur, organisation) }

    it "expose expire/converti/facture_generee, jamais l'email de l'acteur" do
      devis = create(:devis, :avec_ligne, organisation: organisation, client: client)

      get "/api/v1/devis/#{devis.id}"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body).to have_key("expire")
      expect(body).to have_key("converti")
      expect(body["converti"]).to be(false)
      expect(body["facture_generee"]).to be_nil

      expect(response.body).not_to include(utilisateur.email)
    end

    it "expose la référence (id + numéro) de la facture générée après conversion" do
      devis = create(:devis, :avec_ligne, organisation: organisation, client: client)
      post "/api/v1/devis/#{devis.id}/envoyer"
      post "/api/v1/devis/#{devis.id}/accepter"
      post "/api/v1/devis/#{devis.id}/convertir"
      facture_id = JSON.parse(response.body)["id"]

      get "/api/v1/devis/#{devis.id}"

      body = JSON.parse(response.body)
      expect(body["converti"]).to be(true)
      expect(body["facture_generee"]["id"]).to eq(facture_id)
      expect(body["facture_generee"]).not_to have_key("pdf_url")
      expect(body["facture_generee"]).not_to have_key("url")
    ensure
      FileUtils.rm_rf(Rails.root.join("storage", Rails.env, "factures", facture_id.to_s)) if defined?(facture_id) && facture_id
    end
  end
end
