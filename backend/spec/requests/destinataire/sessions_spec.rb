# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Destinataire::Sessions", type: :request do
  let!(:compte) { create(:compte_destinataire, email: "connexion@test.fr", mot_de_passe: "motdepasse123") }

  describe "POST /destinataire/connexion" do
    it "bons identifiants -> 200, session ouverte, cookies posés" do
      post "/destinataire/connexion", params: { email: "connexion@test.fr", mot_de_passe: "motdepasse123" }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["email"]).to eq("connexion@test.fr")
      expect(response.cookies["destinataire_access_token"]).to be_present
      expect(response.cookies["destinataire_refresh_token"]).to be_present
    end

    it "e-mail inconnu -> 401 générique (même message qu'un mauvais mot de passe)" do
      post "/destinataire/connexion", params: { email: "inconnu@test.fr", mot_de_passe: "peuimporte123" }

      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)["error"]).to eq("E-mail ou mot de passe invalide")
    end

    it "mauvais mot de passe -> 401, EXACTEMENT le même message que e-mail inconnu (aucune énumération)" do
      compte

      post "/destinataire/connexion", params: { email: "connexion@test.fr", mot_de_passe: "faux-mot-de-passe" }

      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)["error"]).to eq("E-mail ou mot de passe invalide")
    end
  end

  describe "DELETE /destinataire/connexion" do
    it "révoque la session courante" do
      post "/destinataire/connexion", params: { email: "connexion@test.fr", mot_de_passe: "motdepasse123" }
      access_cookie = response.cookies["destinataire_access_token"]

      delete "/destinataire/connexion", headers: { "Cookie" => "destinataire_access_token=#{access_cookie}" }

      expect(response).to have_http_status(:ok)
      expect(DestinataireSession.last.revoque_at).to be_present
    end

    it "sans authentification -> 401" do
      delete "/destinataire/connexion"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  # ⚠️ DÉCISIF (§1.3) — testé aux DEUX niveaux (service, déjà fait) ET requête.
  describe "CONFUSION DE TOKEN (décisif sécurité, niveau requête)" do
    it "un token DESTINATAIRE ne donne AUCUN accès à une route api/v1 de l'app" do
      post "/destinataire/connexion", params: { email: "connexion@test.fr", mot_de_passe: "motdepasse123" }
      access_cookie = response.cookies["destinataire_access_token"]

      get "/api/v1/factures", headers: { "Cookie" => "access_token=#{access_cookie}" }

      expect(response).to have_http_status(:unauthorized)
    end

    it "un token APP ne donne AUCUN accès à une route destinataire (GET /destinataire/moi)" do
      organisation = create(:organisation)
      utilisateur = create(:utilisateur, organisation: organisation)
      session_app = Session.create!(
        utilisateur: utilisateur, organisation: organisation,
        refresh_token_hash: Digest::SHA256.hexdigest(SecureRandom.hex(64)),
        expire_at: 7.days.from_now
      )
      token_app = AuthTokenService.encode(utilisateur: utilisateur, organisation: organisation, session: session_app)

      get "/destinataire/moi", headers: { "Cookie" => "destinataire_access_token=#{token_app}" }

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
