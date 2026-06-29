# frozen_string_literal: true

require "rails_helper"
require "digest"

RSpec.describe "Api::V1::Auth sécurité", type: :request do
  def set_cookie_header
    Array(response.headers["Set-Cookie"]).join("\n")
  end

  def set_cookie_header_downcase
    set_cookie_header.downcase
  end

  before do
    Rails.cache.clear
  end

  after do
    Rails.cache.clear
  end

  describe "POST /api/v1/auth/login" do
    it "pose access_token et refresh_token en cookies HttpOnly sans exposer les tokens dans le JSON" do
      utilisateur = create(:utilisateur)

      post "/api/v1/auth/login", params: {
        email: utilisateur.email.upcase,
        password: "Sereno123!"
      }

      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)

      expect(json["message"]).to eq("Connexion réussie")
      expect(json.to_s).not_to include(cookies[:access_token].to_s)
      expect(json.to_s).not_to include(cookies[:refresh_token].to_s)

      expect(cookies[:access_token]).to be_present
      expect(cookies[:refresh_token]).to be_present

      expect(set_cookie_header).to include("access_token=")
      expect(set_cookie_header).to include("refresh_token=")
      expect(set_cookie_header_downcase).to include("httponly")
      expect(set_cookie_header_downcase).to include("samesite=lax")

      session = utilisateur.sessions.last

      expect(session.refresh_token_hash).to eq(Digest::SHA256.hexdigest(cookies[:refresh_token]))
      expect(session.refresh_token_hash).not_to eq(cookies[:refresh_token])
    end

    it "limite les tentatives de connexion échouées" do
      utilisateur = create(:utilisateur)

      5.times do
        post "/api/v1/auth/login", params: {
          email: utilisateur.email,
          password: "mauvais-mot-de-passe"
        }

        expect(response).to have_http_status(:unauthorized)
      end

      post "/api/v1/auth/login", params: {
        email: utilisateur.email,
        password: "mauvais-mot-de-passe"
      }

      expect(response).to have_http_status(:too_many_requests)
      expect(JSON.parse(response.body)["error"]).to eq("Trop de tentatives, réessayez dans quelques instants")
    end
  end

  describe "POST /api/v1/auth/refresh" do
    it "refuse un refresh sans cookie refresh_token" do
      post "/api/v1/auth/refresh"

      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)["error"]).to eq("Refresh token manquant")
    end

    it "renouvelle l'access_token et effectue une rotation du refresh_token" do
      utilisateur = create(:utilisateur)

      post "/api/v1/auth/login", params: {
        email: utilisateur.email,
        password: "Sereno123!"
      }

      ancien_access_token = cookies[:access_token]
      ancien_refresh_token = cookies[:refresh_token]
      ancienne_session = utilisateur.sessions.last
      ancien_refresh_token_hash = ancienne_session.refresh_token_hash

      post "/api/v1/auth/refresh"

      expect(response).to have_http_status(:ok)

      nouveau_access_token = cookies[:access_token]
      nouveau_refresh_token = cookies[:refresh_token]

      ancienne_session.reload

      expect(nouveau_access_token).to be_present
      expect(nouveau_refresh_token).to be_present
      expect(nouveau_access_token).not_to eq(ancien_access_token)
      expect(nouveau_refresh_token).not_to eq(ancien_refresh_token)

      expect(ancienne_session.refresh_token_hash).to eq(Digest::SHA256.hexdigest(nouveau_refresh_token))
      expect(ancienne_session.refresh_token_hash).not_to eq(ancien_refresh_token_hash)
      expect(ancienne_session.refresh_token_hash).not_to eq(nouveau_refresh_token)
    end

    it "refuse l'ancien refresh_token après rotation" do
      utilisateur = create(:utilisateur)

      post "/api/v1/auth/login", params: {
        email: utilisateur.email,
        password: "Sereno123!"
      }

      ancien_refresh_token = cookies[:refresh_token]

      post "/api/v1/auth/refresh"

      expect(response).to have_http_status(:ok)

      cookies[:refresh_token] = ancien_refresh_token

      post "/api/v1/auth/refresh"

      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)["error"]).to eq("Session invalide")
    end
  end

  describe "DELETE /api/v1/auth/logout" do
    it "révoque la session et supprime les cookies d'authentification" do
      utilisateur = create(:utilisateur)

      post "/api/v1/auth/login", params: {
        email: utilisateur.email,
        password: "Sereno123!"
      }

      session = utilisateur.sessions.last

      delete "/api/v1/auth/logout"

      expect(response).to have_http_status(:ok)
      expect(session.reload).to be_revoquee

      expect(set_cookie_header).to include("access_token=")
      expect(set_cookie_header).to include("refresh_token=")
      expect(set_cookie_header_downcase).to include("max-age=0")
      expect(set_cookie_header_downcase).to include("expires=")
    end
  end
end
