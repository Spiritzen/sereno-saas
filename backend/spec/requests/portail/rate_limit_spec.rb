# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Portail::Factures rate limiting (dette n°33)", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  describe "T-RATE-LIMIT (par IP, compteur PARTAGÉ entre show/pdf/avoirs)" do
    it "60 requêtes en alternant les 3 routes passent, la 61e est throttlée" do
      token = SecureRandom.hex(64) # jamais généré : réponse applicative normale = 404
      chemins = [
        "/portail/factures/#{token}",
        "/portail/factures/#{token}/pdf",
        "/portail/factures/#{token}/avoirs"
      ]

      # Temps figé (même discipline que webhooks/pa_rate_limit_spec.rb) :
      # Rack::Attack::Cache bucket sa fenêtre sur Time.now.to_i / period
      # (60 s) — sans figer le temps, 61 requêtes réelles peuvent s'étaler
      # au-delà de 60 s sur une machine/CI lente, la fenêtre se réinitialise
      # en cours et la 61e repasse sous le seuil (flaky, pas un bug du code).
      freeze_time do
        61.times do |i|
          get chemins[i % 3], env: { "REMOTE_ADDR" => "203.0.113.10" }

          if i < 60
            # Les 60 premières restent la réponse APPLICATIVE normale du
            # token invalide — jamais throttlées avant le seuil.
            expect(response).to have_http_status(:not_found)
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

  describe "T-RATE-LIMIT-ISOLATION-IP" do
    it "une IP B, fraîche, n'est PAS affectée par la saturation de l'IP A" do
      freeze_time do
        token_a = SecureRandom.hex(64)

        61.times do
          get "/portail/factures/#{token_a}", env: { "REMOTE_ADDR" => "192.0.2.50" }
        end
        expect(response).to have_http_status(:too_many_requests) # IP A saturée

        token_b = SecureRandom.hex(64)
        get "/portail/factures/#{token_b}", env: { "REMOTE_ADDR" => "198.51.100.77" }

        expect(response).to have_http_status(:not_found)
        expect(JSON.parse(response.body)).to eq({ "error" => "Lien invalide ou expiré" })
      end
    end
  end

  describe "T-AUTRES-ROUTES" do
    it "ne throttle pas une route API authentifiée, même au-delà de 60 requêtes/minute" do
      organisation = create(:organisation)
      utilisateur = create(:utilisateur, organisation: organisation)

      allow_any_instance_of(Api::V1::BaseController)
        .to receive(:authenticate_request!) do
          Current.organisation = organisation
          Current.utilisateur = utilisateur
        end

      freeze_time do
        61.times do
          get "/api/v1/clients", headers: {}, env: { "REMOTE_ADDR" => "203.0.113.201" }
          expect(response).not_to have_http_status(:too_many_requests)
        end
      end

      Current.reset
    end
  end
end
