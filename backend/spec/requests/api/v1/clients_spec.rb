# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Clients", type: :request do
  def authenticate_as(utilisateur, organisation)
    allow_any_instance_of(Api::V1::BaseController)
      .to receive(:authenticate_request!) do
        Current.organisation = organisation
        Current.utilisateur = utilisateur
        Current.session = nil
      end
  end

  def valid_client_params(attributes = {})
    {
      type: "entreprise",
      raison_sociale: "Client Secure SAS",
      siret: "12345678901234",
      numero_tva: "FR12345678901",
      adresse_ligne1: "10 rue des Tests",
      adresse_ligne2: nil,
      code_postal: "80000",
      ville: "Amiens",
      pays: "FR",
      email: "client.secure@example.fr",
      telephone: "0102030405",
      identifiant_routage_pa: "ROUTAGE-SECURE",
      notes: "Client créé depuis les specs"
    }.merge(attributes)
  end

  after do
    Current.reset
  end

  describe "isolation tenant" do
    let(:organisation_a) { create(:organisation) }
    let(:organisation_b) { create(:organisation) }
    let(:utilisateur_a) { create(:utilisateur, organisation: organisation_a, role: "owner") }

    before do
      authenticate_as(utilisateur_a, organisation_a)
    end

    it "autorise la lecture d'un client de sa propre organisation" do
      client = create(:client, organisation: organisation_a)

      get "/api/v1/clients/#{client.id}"

      expect(response).to have_http_status(:ok)
    end

    it "empêche la lecture d'un client appartenant à une autre organisation" do
      client = create(:client, organisation: organisation_b)

      get "/api/v1/clients/#{client.id}"

      expect(response).to have_http_status(:not_found)
    end

    it "empêche la modification d'un client appartenant à une autre organisation" do
      client = create(:client, organisation: organisation_b)
      ancienne_raison_sociale = client.raison_sociale

      patch "/api/v1/clients/#{client.id}", params: {
        client: {
          raison_sociale: "Tentative cross-tenant"
        }
      }

      expect(response).to have_http_status(:not_found)

      client.reload
      expect(client.raison_sociale).to eq(ancienne_raison_sociale)
    end
  end

  describe "création client" do
    let(:organisation) { create(:organisation) }
    let(:utilisateur) { create(:utilisateur, organisation: organisation, role: "owner") }

    before do
      authenticate_as(utilisateur, organisation)
    end

    it "crée un client actif valide" do
      expect do
        post "/api/v1/clients", params: {
          client: valid_client_params
        }
      end.to change(Client, :count).by(1)

      expect(response).to have_http_status(:created)

      client = Client.order(:created_at).last
      expect(client.organisation_id).to eq(organisation.id)
      expect(client.raison_sociale).to eq("Client Secure SAS")
      expect(client.statut).to eq("actif")
    end

    it "force le statut actif à la création même si un statut archive est envoyé" do
      post "/api/v1/clients", params: {
        client: valid_client_params(
          raison_sociale: "Client Archive Injection SAS",
          siret: "12345678901235",
          statut: "archive"
        )
      }

      expect(response).to have_http_status(:created)

      client = Client.find_by!(raison_sociale: "Client Archive Injection SAS")
      expect(client.statut).to eq("actif")
    end

    it "refuse un client entreprise sans SIRET" do
      expect do
        post "/api/v1/clients", params: {
          client: valid_client_params(siret: nil)
        }
      end.not_to change(Client, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "autorise un client particulier sans SIRET" do
      expect do
        post "/api/v1/clients", params: {
          client: valid_client_params(
            type: "particulier",
            raison_sociale: "Jean Test",
            siret: nil,
            numero_tva: nil
          )
        }
      end.to change(Client, :count).by(1)

      expect(response).to have_http_status(:created)

      client = Client.find_by!(raison_sociale: "Jean Test")
      expect(client.type).to eq("particulier")
      expect(client.siret).to be_nil
    end
  end

  describe "modification client" do
    let(:organisation) { create(:organisation) }
    let(:utilisateur) { create(:utilisateur, organisation: organisation, role: "owner") }

    before do
      authenticate_as(utilisateur, organisation)
    end

    it "modifie les informations métier d'un client" do
      client = create(:client, organisation: organisation)

      patch "/api/v1/clients/#{client.id}", params: {
        client: {
          raison_sociale: "Client Modifié SAS",
          ville: "Lille",
          notes: "Note modifiée"
        }
      }

      expect(response).to have_http_status(:ok)

      client.reload
      expect(client.raison_sociale).to eq("Client Modifié SAS")
      expect(client.ville).to eq("Lille")
      expect(client.notes).to eq("Note modifiée")
    end

    it "ignore une tentative de changement direct du statut via update" do
      client = create(:client, organisation: organisation, statut: "actif")

      patch "/api/v1/clients/#{client.id}", params: {
        client: {
          raison_sociale: "Client Toujours Actif SAS",
          statut: "archive"
        }
      }

      expect(response).to have_http_status(:ok)

      client.reload
      expect(client.raison_sociale).to eq("Client Toujours Actif SAS")
      expect(client.statut).to eq("actif")
    end
  end

  describe "archivage client" do
    let(:organisation) { create(:organisation) }
    let(:owner) { create(:utilisateur, organisation: organisation, role: "owner") }
    let(:comptable) { create(:utilisateur, organisation: organisation, role: "comptable") }

    it "autorise un owner à archiver un client" do
      authenticate_as(owner, organisation)

      client = create(:client, organisation: organisation, statut: "actif")

      patch "/api/v1/clients/#{client.id}/archive"

      expect(response).to have_http_status(:ok)

      client.reload
      expect(client.statut).to eq("archive")
    end

    it "refuse à un comptable d'archiver un client" do
      authenticate_as(comptable, organisation)

      client = create(:client, organisation: organisation, statut: "actif")

      patch "/api/v1/clients/#{client.id}/archive"

      expect(response).to have_http_status(:forbidden)

      client.reload
      expect(client.statut).to eq("actif")
    end
  end

  describe "suppression client" do
    let(:organisation) { create(:organisation) }
    let(:utilisateur) { create(:utilisateur, organisation: organisation, role: "owner") }

    before do
      authenticate_as(utilisateur, organisation)
    end

    it "autorise la suppression d'un client sans document métier lié" do
      client = create(:client, organisation: organisation)

      expect do
        delete "/api/v1/clients/#{client.id}"
      end.to change(Client, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it "refuse la suppression d'un client lié à une facture" do
      client = create(:client, organisation: organisation)
      create(:facture, organisation: organisation, client: client)

      expect do
        delete "/api/v1/clients/#{client.id}"
      end.not_to change(Client, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(Client.exists?(client.id)).to be(true)
    end
  end
end
