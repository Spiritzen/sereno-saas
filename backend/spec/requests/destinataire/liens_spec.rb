# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Destinataire::Liens", type: :request do
  def authenticate_as(compte)
    session = DestinataireSession.generer!(compte_destinataire: compte).session
    allow_any_instance_of(Destinataire::BaseController)
      .to receive(:authenticate_destinataire!) do
        Current.compte_destinataire = compte
        Current.destinataire_session = session
      end
  end

  after { Current.reset }

  describe "POST /destinataire/liens" do
    it "revendique un DEUXIÈME fournisseur via un nouveau token de portail" do
      compte = create(:compte_destinataire)
      authenticate_as(compte)

      autre_organisation = create(:organisation)
      autre_client = create(:client, organisation: autre_organisation)
      autre_facture = create(:facture, :emise, organisation: autre_organisation, client: autre_client, date_echeance: 1.day.ago)
      resultat_token = PortailFactureToken.generer!(facture: autre_facture)

      expect {
        post "/destinataire/liens", params: { token: resultat_token.brut }
      }.to change(compte.destinataire_client_links, :count).by(1)

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["client_id"]).to eq(autre_client.id)
      expect(body["deja_lie"]).to eq(false)
    end

    it "idempotent : revendiquer le même client une 2e fois ne crée PAS de doublon" do
      compte = create(:compte_destinataire)
      authenticate_as(compte)

      organisation = create(:organisation)
      client = create(:client, organisation: organisation)
      facture = create(:facture, :emise, organisation: organisation, client: client, date_echeance: 1.day.ago)

      premier_token = PortailFactureToken.generer!(facture: facture)
      post "/destinataire/liens", params: { token: premier_token.brut }
      expect(response).to have_http_status(:created)

      second_token = PortailFactureToken.generer!(facture: facture)

      expect {
        post "/destinataire/liens", params: { token: second_token.brut }
      }.not_to change(compte.destinataire_client_links, :count)

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["deja_lie"]).to eq(true)
    end

    it "token invalide -> 422 générique, aucune écriture" do
      compte = create(:compte_destinataire)
      authenticate_as(compte)

      expect {
        post "/destinataire/liens", params: { token: SecureRandom.hex(64) }
      }.not_to change(DestinataireClientLink, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "sans authentification -> 401, aucune écriture" do
      organisation = create(:organisation)
      client = create(:client, organisation: organisation)
      facture = create(:facture, :emise, organisation: organisation, client: client, date_echeance: 1.day.ago)
      resultat_token = PortailFactureToken.generer!(facture: facture)

      expect {
        post "/destinataire/liens", params: { token: resultat_token.brut }
      }.not_to change(DestinataireClientLink, :count)

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
