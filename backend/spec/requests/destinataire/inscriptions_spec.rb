# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Destinataire::Inscriptions", type: :request do
  let(:organisation) { create(:organisation) }
  let(:client_facture) { create(:client, organisation: organisation) }
  let(:facture) { create(:facture, :emise, organisation: organisation, client: client_facture, date_echeance: 1.day.ago) }

  describe "POST /destinataire/inscription" do
    it "avec un token de portail ACTIF : crée le compte + le premier lien + ouvre une session" do
      resultat_token = PortailFactureToken.generer!(facture: facture)

      expect {
        post "/destinataire/inscription", params: {
          token: resultat_token.brut, email: "nouveau@test.fr", mot_de_passe: "motdepasse123"
        }
      }.to change(CompteDestinataire, :count).by(1)
        .and change(DestinataireClientLink, :count).by(1)
        .and change(DestinataireSession, :count).by(1)

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["email"]).to eq("nouveau@test.fr")
      expect(body["fournisseurs_lies"]).to eq(1)

      lien = DestinataireClientLink.last
      expect(lien.client_id).to eq(client_facture.id)
      expect(lien.cree_via).to eq("lien_portail")
      expect(lien.facture_id_preuve).to eq(facture.id)

      expect(response.cookies["destinataire_access_token"]).to be_present
      expect(response.cookies["destinataire_refresh_token"]).to be_present
    end

    it "token INCONNU -> 422 générique, aucune écriture" do
      expect {
        post "/destinataire/inscription", params: {
          token: SecureRandom.hex(64), email: "x@test.fr", mot_de_passe: "motdepasse123"
        }
      }.not_to change(CompteDestinataire, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["error"]).to eq("Lien invalide ou expiré")
    end

    it "token EXPIRÉ -> la MÊME réponse générique" do
      resultat_token = PortailFactureToken.generer!(facture: facture)
      resultat_token.token.update_columns(expire_at: 1.minute.ago)

      post "/destinataire/inscription", params: {
        token: resultat_token.brut, email: "x@test.fr", mot_de_passe: "motdepasse123"
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["error"]).to eq("Lien invalide ou expiré")
    end

    it "token RÉVOQUÉ -> la MÊME réponse générique" do
      resultat_token = PortailFactureToken.generer!(facture: facture)
      resultat_token.token.revoquer!

      post "/destinataire/inscription", params: {
        token: resultat_token.brut, email: "x@test.fr", mot_de_passe: "motdepasse123"
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["error"]).to eq("Lien invalide ou expiré")
    end

    it "e-mail déjà pris -> 422 explicite (UX d'inscription, pas une fuite tierce)" do
      create(:compte_destinataire, email: "existe@test.fr")
      resultat_token = PortailFactureToken.generer!(facture: facture)

      expect {
        post "/destinataire/inscription", params: {
          token: resultat_token.brut, email: "existe@test.fr", mot_de_passe: "motdepasse123"
        }
      }.not_to change(CompteDestinataire, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["error"]).to include("connectez-vous")
    end

    it "mot de passe trop court -> 422, aucune écriture" do
      resultat_token = PortailFactureToken.generer!(facture: facture)

      expect {
        post "/destinataire/inscription", params: {
          token: resultat_token.brut, email: "court@test.fr", mot_de_passe: "court"
        }
      }.not_to change(CompteDestinataire, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
