# frozen_string_literal: true

require "rails_helper"
require "fileutils"

RSpec.describe "Api::V1::EvenementsDevis", type: :request do
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

    get "/api/v1/devis/#{devis.id}/evenements"

    expect(response).to have_http_status(:unauthorized)
  end

  describe "A. isolation tenant stricte" do
    let(:organisation_a) { create(:organisation) }
    let(:organisation_b) { create(:organisation) }
    let(:utilisateur_a) { create(:utilisateur, organisation: organisation_a, role: "owner") }
    let(:utilisateur_b) { create(:utilisateur, organisation: organisation_b, role: "owner") }
    let(:client_a) { create(:client, organisation: organisation_a) }

    def envoyer_devis_a
      authenticate_as(utilisateur_a, organisation_a)
      devis = create(:devis, :avec_ligne, organisation: organisation_a, client: client_a)

      post "/api/v1/devis/#{devis.id}/envoyer"

      JSON.parse(response.body)["id"]
    end

    it "refuse à l'organisation B la lecture des événements d'un devis de A (404, jamais 403)" do
      devis_a_id = envoyer_devis_a

      authenticate_as(utilisateur_b, organisation_b)
      get "/api/v1/devis/#{devis_a_id}/evenements"

      expect(response).to have_http_status(:not_found)
    end

    it "ne laisse fuiter aucun événement de A dans la réponse à B" do
      devis_a_id = envoyer_devis_a

      authenticate_as(utilisateur_b, organisation_b)
      get "/api/v1/devis/#{devis_a_id}/evenements"

      expect(response.body).not_to match(/envoye|devis_envoye/)
    end

    it "autorise A à lire les événements de son propre devis" do
      devis_a_id = envoyer_devis_a

      get "/api/v1/devis/#{devis_a_id}/evenements"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)

      expect(body).not_to be_empty
      expect(body.first["statut"]).to eq("envoye")
    end
  end

  describe "D. lecture seule stricte (T-APPEND-ONLY, décisif)" do
    let(:organisation) { create(:organisation) }
    let(:utilisateur) { create(:utilisateur, organisation: organisation, role: "owner") }
    let(:devis) { create(:devis, organisation: organisation, client: create(:client, organisation: organisation)) }

    before { authenticate_as(utilisateur, organisation) }

    it "ne route aucune action de création sur /evenements" do
      post "/api/v1/devis/#{devis.id}/evenements", params: { evenement_devis: { statut: "envoye" } }

      expect(response).to have_http_status(:not_found)
    end

    it "ne route aucune action de modification sur /evenements" do
      patch "/api/v1/devis/#{devis.id}/evenements/#{SecureRandom.uuid}"

      expect(response).to have_http_status(:not_found)
    end

    it "ne route aucune action de suppression sur /evenements" do
      delete "/api/v1/devis/#{devis.id}/evenements/#{SecureRandom.uuid}"

      expect(response).to have_http_status(:not_found)
    end

    it "un update direct d'un EvenementDevis lève (append-only, modèle)" do
      evenement = create(:evenement_devis, devis: devis, organisation: organisation)

      expect { evenement.update!(statut: "accepte") }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "un destroy direct d'un EvenementDevis lève (append-only, modèle)" do
      evenement = create(:evenement_devis, devis: devis, organisation: organisation)

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

    it "n'expose jamais l'email de l'acteur sur un événement de conversion réel" do
      devis = create(:devis, :avec_ligne, organisation: organisation, client: client)
      post "/api/v1/devis/#{devis.id}/envoyer"
      post "/api/v1/devis/#{devis.id}/accepter"
      post "/api/v1/devis/#{devis.id}/convertir"
      facture_id = JSON.parse(response.body)["id"]

      get "/api/v1/devis/#{devis.id}/evenements"
      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      evenement_conversion = body.find { |evenement| evenement["details"]["action"] == "devis_converti" }

      expect(evenement_conversion).not_to be_nil
      expect(evenement_conversion["details"]["facture_id"]).to eq(facture_id)
      expect(evenement_conversion["actor"]).to eq("id" => utilisateur.id, "display_name" => "Ada Lovelace")

      expect(response.body).not_to include(utilisateur.email)
    ensure
      FileUtils.rm_rf(Rails.root.join("storage", Rails.env, "factures", facture_id.to_s)) if defined?(facture_id) && facture_id
    end
  end

  describe "G. boucle complète envoi → acceptation → conversion → lecture (T-BOUCLE)" do
    let(:organisation) { create(:organisation) }
    let(:utilisateur) { create(:utilisateur, organisation: organisation, role: "owner") }
    let(:client) { create(:client, organisation: organisation) }

    before { authenticate_as(utilisateur, organisation) }

    it "les trois événements apparaissent dans l'ordre, via GET evenements" do
      devis = create(:devis, :avec_ligne, organisation: organisation, client: client)

      post "/api/v1/devis/#{devis.id}/envoyer"
      post "/api/v1/devis/#{devis.id}/accepter"
      post "/api/v1/devis/#{devis.id}/convertir"
      facture_id = JSON.parse(response.body)["id"]

      get "/api/v1/devis/#{devis.id}/evenements"
      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body.length).to eq(3)
      expect(body.map { |evenement| evenement["details"]["action"] })
        .to eq(%w[devis_envoye devis_accepte devis_converti])
    ensure
      FileUtils.rm_rf(Rails.root.join("storage", Rails.env, "factures", facture_id.to_s)) if defined?(facture_id) && facture_id
    end
  end
end
