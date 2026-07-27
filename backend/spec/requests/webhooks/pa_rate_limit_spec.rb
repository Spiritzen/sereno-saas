# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Webhooks::Pa rate limiting (R6)", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  # provider_event_id varie à chaque appel pour ne jamais dépendre de la
  # déduplication (hors sujet ici) : seul le code HTTP nous intéresse. Le
  # statut candidat retombera vite sur "stale" une fois la facture passée à
  # "recue", ce qui reste un 200 -- aucune de ces requêtes n'est une erreur
  # applicative, exactement ce qu'il faut pour isoler le SEUL comportement
  # de rate limiting.
  def payload(identifiant_pa:)
    { identifiant_pa: identifiant_pa, statut_brut: "SANDBOX_RECEIVED", provider_event_id: SecureRandom.hex(8) }.to_json
  end

  def creer_notification(organisation: create(:organisation))
    secret = webhook_secret
    plateforme = create(:plateforme_agreee, organisation: organisation, webhook_secret_chiffre: secret)
    facture = create(:facture, :deposee, organisation: organisation)
    transmission = create(
      :transmission_pa, :depose, organisation: organisation, facture: facture, plateforme_agreee: plateforme
    )

    [ transmission, secret ]
  end

  describe "T-RATE-LIMIT (par IP)" do
    it "60 requêtes depuis la MÊME IP passent, la 61e est throttlée" do
      transmission, secret = creer_notification

      # Temps figé (§1/§4 du prompt) : Rack::Attack::Cache bucket sa fenêtre
      # sur Time.now.to_i / period (60 s) — sans figer le temps, 61 requêtes
      # réelles peuvent s'étaler au-delà de 60 s sur une machine/CI lente, la
      # fenêtre se réinitialise en cours et la 61e repasse à 200 (flaky, pas
      # un bug du code R6). freeze_time stubbe Time.now : la boucle entière
      # est traitée comme un seul instant, quelle que soit la durée réelle.
      freeze_time do
        61.times do |i|
          post_webhook_pa(
            raw_body: payload(identifiant_pa: transmission.identifiant_pa),
            secret: secret,
            remote_addr: "203.0.113.10"
          )

          if i < 60
            expect(response).to have_http_status(:ok)
          else
            expect(response).to have_http_status(:too_many_requests)
            expect(JSON.parse(response.body)).to eq({ "error" => "rate_limited" })
            expect(response.headers["Retry-After"]).to be_present
          end
        end
      end
    end
  end

  describe "T-RATE-LIMIT-ORGANISATION" do
    it "60 requêtes pour la MÊME organisation (IP différente à chaque fois) passent, la 61e est throttlée" do
      transmission, secret = creer_notification

      # Temps figé : voir commentaire équivalent sur T-RATE-LIMIT (par IP).
      freeze_time do
        61.times do |i|
          post_webhook_pa(
            raw_body: payload(identifiant_pa: transmission.identifiant_pa),
            secret: secret,
            remote_addr: "198.51.100.#{i}"
          )

          if i < 60
            expect(response).to have_http_status(:ok)
          else
            expect(response).to have_http_status(:too_many_requests)
          end
        end
      end
    end

    it "une AUTRE organisation, sous son propre seuil, n'est PAS affectée par le throttle de la première" do
      transmission_a, secret_a = creer_notification

      freeze_time do
        61.times do |i|
          post_webhook_pa(
            raw_body: payload(identifiant_pa: transmission_a.identifiant_pa),
            secret: secret_a,
            remote_addr: "198.51.100.#{i}"
          )
        end
        expect(response).to have_http_status(:too_many_requests) # organisation A est à son seuil

        # organisation_b, fraîche, n'a jamais approché son propre seuil.
        transmission_b, secret_b = creer_notification
        post_webhook_pa(
          raw_body: payload(identifiant_pa: transmission_b.identifiant_pa),
          secret: secret_b,
          remote_addr: "198.51.100.201"
        )
        expect(response).to have_http_status(:ok)
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

      # Temps figé par homogénéité avec les autres exemples de ce fichier
      # (§4 du prompt), même si cet exemple ne dépend pas du minutage pour
      # rester vert (il n'affirme jamais 429).
      freeze_time do
        61.times do
          get "/api/v1/clients", headers: {}, env: { "REMOTE_ADDR" => "203.0.113.10" }
          expect(response).not_to have_http_status(:too_many_requests)
        end
      end

      Current.reset
    end
  end
end
