# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Destinataire connexion/inscription rate limiting (dette n°43)", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  describe "T-RATE-LIMIT — connexion (par IP)" do
    it "5 tentatives passent en réponse applicative normale, la 6e est throttlée" do
      freeze_time do
        6.times do |i|
          post "/destinataire/connexion",
               params: { email: "inconnu@example.test", mot_de_passe: "peu-importe" },
               env: { "REMOTE_ADDR" => "203.0.113.20" }

          if i < 5
            expect(response).to have_http_status(:unauthorized)
            expect(JSON.parse(response.body)).to eq({ "error" => "E-mail ou mot de passe invalide" })
          else
            expect(response).to have_http_status(:too_many_requests)
            expect(JSON.parse(response.body)).to eq({ "error" => "rate_limited" })
            expect(response.headers["Retry-After"]).to be_present
          end
        end
      end
    end
  end

  describe "T-RATE-LIMIT — inscription (par IP)" do
    it "5 tentatives passent en réponse applicative normale, la 6e est throttlée" do
      freeze_time do
        6.times do |i|
          post "/destinataire/inscription",
               params: { token: "token-jamais-genere", email: "quelqu-un@example.test", mot_de_passe: "peu-importe" },
               env: { "REMOTE_ADDR" => "203.0.113.21" }

          if i < 5
            expect(response).to have_http_status(:unprocessable_entity)
            expect(JSON.parse(response.body)).to eq({ "error" => "Lien invalide ou expiré" })
          else
            expect(response).to have_http_status(:too_many_requests)
            expect(JSON.parse(response.body)).to eq({ "error" => "rate_limited" })
            expect(response.headers["Retry-After"]).to be_present
          end
        end
      end
    end
  end

  describe "T-RATE-LIMIT-COMPTEURS-DISTINCTS" do
    it "saturer la connexion ne throttle PAS l'inscription, sur la même IP" do
      freeze_time do
        6.times do
          post "/destinataire/connexion",
               params: { email: "inconnu@example.test", mot_de_passe: "peu-importe" },
               env: { "REMOTE_ADDR" => "203.0.113.22" }
        end
        expect(response).to have_http_status(:too_many_requests) # connexion saturée

        post "/destinataire/inscription",
             params: { token: "autre-token-jamais-genere", email: "autre@example.test", mot_de_passe: "peu-importe" },
             env: { "REMOTE_ADDR" => "203.0.113.22" }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)).to eq({ "error" => "Lien invalide ou expiré" })
      end
    end
  end

  describe "T-RATE-LIMIT-ISOLATION-IP" do
    it "une IP B, fraîche, n'est pas affectée par la saturation de connexion depuis l'IP A" do
      freeze_time do
        6.times do
          post "/destinataire/connexion",
               params: { email: "inconnu@example.test", mot_de_passe: "peu-importe" },
               env: { "REMOTE_ADDR" => "192.0.2.60" }
        end
        expect(response).to have_http_status(:too_many_requests) # IP A saturée

        post "/destinataire/connexion",
             params: { email: "inconnu@example.test", mot_de_passe: "peu-importe" },
             env: { "REMOTE_ADDR" => "198.51.100.88" }

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)).to eq({ "error" => "E-mail ou mot de passe invalide" })
      end
    end
  end

  describe "T-AUTRES-ROUTES" do
    it "ne throttle pas une route Destinataire authentifiée, même au-delà de 5 requêtes/minute" do
      compte = create(:compte_destinataire)

      allow_any_instance_of(Destinataire::BaseController)
        .to receive(:authenticate_destinataire!) do
          Current.compte_destinataire = compte
        end

      freeze_time do
        6.times do
          get "/destinataire/moi", env: { "REMOTE_ADDR" => "203.0.113.202" }
          expect(response).not_to have_http_status(:too_many_requests)
        end
      end

      Current.reset
    end

    it "ne throttle pas l'inscription OWNER api/v1, même au-delà de 5 requêtes/minute sur la même IP" do
      freeze_time do
        6.times do
          post "/destinataire/connexion",
               params: { email: "inconnu@example.test", mot_de_passe: "peu-importe" },
               env: { "REMOTE_ADDR" => "203.0.113.203" }
        end
        expect(response).to have_http_status(:too_many_requests) # connexion destinataire saturée

        post "/api/v1/inscription",
             params: {
               inscription: {
                 utilisateur: {
                   prenom: "Test",
                   nom: "Isolation",
                   email: "isolation-throttle@example.test",
                   mot_de_passe: "mot-de-passe-solide",
                   confirmation_mot_de_passe: "mot-de-passe-solide"
                 },
                 organisation: {
                   raison_sociale: "Isolation SARL",
                   siret: "13579246801357",
                   regime_tva: "reel_normal",
                   adresse_ligne1: "1 rue de la Paix",
                   code_postal: "80000",
                   ville: "Amiens",
                   pays: "FR",
                   email: "isolation@example.test"
                 }
               }
             },
             env: { "REMOTE_ADDR" => "203.0.113.203" }

        expect(response).to have_http_status(:created)
      end
    end
  end
end
