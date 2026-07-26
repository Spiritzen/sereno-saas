# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Webhooks::Pa#recevoir", type: :request do
  def payload(identifiant_pa:, statut_brut:, provider_event_id: SecureRandom.hex(8), occurred_at: Time.current.utc.iso8601)
    {
      identifiant_pa: identifiant_pa,
      statut_brut: statut_brut,
      provider_event_id: provider_event_id,
      occurred_at: occurred_at
    }.to_json
  end

  let(:organisation) { create(:organisation) }
  let(:secret) { webhook_secret }
  let!(:plateforme) { create(:plateforme_agreee, organisation: organisation, webhook_secret_chiffre: secret) }
  let(:facture) { create(:facture, :deposee, organisation: organisation) }
  let!(:transmission) do
    create(:transmission_pa, :depose, organisation: organisation, facture: facture, plateforme_agreee: plateforme)
  end

  describe "T-SIGNATURE-KO (décisif sécurité)" do
    it "rejette une signature invalide -> 401, aucune ingestion" do
      body = payload(identifiant_pa: transmission.identifiant_pa, statut_brut: "SANDBOX_RECEIVED")
      compte_avant = EvenementEntrantPa.count

      post_webhook_pa(raw_body: body, secret: secret, signature: "0" * 64)

      expect(response).to have_http_status(:unauthorized)
      expect(EvenementEntrantPa.count).to eq(compte_avant)
      expect(facture.reload.statut).to eq("deposee")
    end

    it "rejette l'absence totale de signature -> 401, aucune ingestion" do
      body = payload(identifiant_pa: transmission.identifiant_pa, statut_brut: "SANDBOX_RECEIVED")
      compte_avant = EvenementEntrantPa.count

      post "/webhooks/pa",
           params: body,
           headers: { "Content-Type" => "application/json", "X-Sereno-Signature-Timestamp" => webhook_timestamp }

      expect(response).to have_http_status(:unauthorized)
      expect(EvenementEntrantPa.count).to eq(compte_avant)
    end

    it "rejette un secret absent côté organisation (plateforme non configurée) -> 401" do
      plateforme.update_columns(webhook_secret_chiffre: nil)
      body = payload(identifiant_pa: transmission.identifiant_pa, statut_brut: "SANDBOX_RECEIVED")

      post_webhook_pa(raw_body: body, secret: secret)

      expect(response).to have_http_status(:unauthorized)
      expect(EvenementEntrantPa.count).to eq(0)
    end
  end

  describe "T-CROSS-TENANT (décisif isolation)" do
    it "une notification signée avec le secret d'une AUTRE organisation est rejetée, aucune facture n'est touchée" do
      organisation_b = create(:organisation)
      secret_b = webhook_secret
      plateforme_b = create(:plateforme_agreee, organisation: organisation_b, webhook_secret_chiffre: secret_b)
      facture_b = create(:facture, :deposee, organisation: organisation_b)
      transmission_b = create(
        :transmission_pa, :depose, organisation: organisation_b, facture: facture_b, plateforme_agreee: plateforme_b
      )

      body = payload(identifiant_pa: transmission_b.identifiant_pa, statut_brut: "SANDBOX_RECEIVED")

      # Signé avec le secret de l'organisation A, envoyé pour une transmission de B.
      post_webhook_pa(raw_body: body, secret: secret)

      expect(response).to have_http_status(:unauthorized)
      expect(EvenementEntrantPa.where(transmission_pa: transmission_b)).to be_empty
      expect(facture_b.reload.statut).to eq("deposee")
      expect(EvenementEntrantPa.where(transmission_pa: transmission)).to be_empty
      expect(facture.reload.statut).to eq("deposee")
    end

    it "une notification correctement signée pour une organisation n'affecte QUE sa propre facture" do
      organisation_b = create(:organisation)
      secret_b = webhook_secret
      plateforme_b = create(:plateforme_agreee, organisation: organisation_b, webhook_secret_chiffre: secret_b)
      facture_b = create(:facture, :deposee, organisation: organisation_b)
      transmission_b = create(
        :transmission_pa, :depose, organisation: organisation_b, facture: facture_b, plateforme_agreee: plateforme_b
      )

      body = payload(identifiant_pa: transmission_b.identifiant_pa, statut_brut: "SANDBOX_RECEIVED")
      post_webhook_pa(raw_body: body, secret: secret_b)

      expect(response).to have_http_status(:ok)
      expect(facture_b.reload.statut).to eq("recue")
      expect(facture.reload.statut).to eq("deposee")
      expect(EvenementEntrantPa.where(transmission_pa: transmission)).to be_empty
    end
  end

  describe "T-SIGNATURE-OK" do
    it "corps + signature valides + timestamp frais -> 200, ingestion réelle" do
      body = payload(identifiant_pa: transmission.identifiant_pa, statut_brut: "SANDBOX_RECEIVED")

      post_webhook_pa(raw_body: body, secret: secret)

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["resultat"]).to eq("applied")
      expect(EvenementEntrantPa.where(transmission_pa: transmission).count).to eq(1)
      expect(facture.reload.statut).to eq("recue")

      evenement = EvenementFacture.order(:created_at).last
      expect(evenement.source).to eq("sandbox")
    end
  end

  describe "T-RAW-BODY" do
    it "valide une signature calculée sur le corps BRUT même si sa re-sérialisation JSON différerait" do
      corps_pretty = JSON.pretty_generate(
        JSON.parse(payload(identifiant_pa: transmission.identifiant_pa, statut_brut: "SANDBOX_RECEIVED"))
      )
      corps_compact_reserialise = JSON.generate(JSON.parse(corps_pretty))
      expect(corps_pretty).not_to eq(corps_compact_reserialise) # les octets diffèrent réellement

      post_webhook_pa(raw_body: corps_pretty, secret: secret)

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["resultat"]).to eq("applied")
    end

    it "rejette une signature calculée sur le corps RE-SÉRIALISÉ plutôt que sur le brut envoyé" do
      corps_pretty = JSON.pretty_generate(
        JSON.parse(payload(identifiant_pa: transmission.identifiant_pa, statut_brut: "SANDBOX_RECEIVED"))
      )
      corps_compact_reserialise = JSON.generate(JSON.parse(corps_pretty))
      timestamp = webhook_timestamp
      signature_sur_reserialise = webhook_signature(secret: secret, raw_body: corps_compact_reserialise, timestamp: timestamp)

      # Corps envoyé = pretty (brut) ; signature = calculée sur le compact (mauvais octets).
      post_webhook_pa(raw_body: corps_pretty, secret: secret, timestamp: timestamp, signature: signature_sur_reserialise)

      expect(response).to have_http_status(:unauthorized)
      expect(EvenementEntrantPa.count).to eq(0)
    end
  end

  describe "T-REJEU-TEMPOREL" do
    it "signature valide mais timestamp hors fenêtre (10 min) -> 401, aucune ingestion" do
      timestamp = webhook_timestamp(decalage: -10.minutes)
      body = payload(identifiant_pa: transmission.identifiant_pa, statut_brut: "SANDBOX_RECEIVED")

      post_webhook_pa(raw_body: body, secret: secret, timestamp: timestamp)

      expect(response).to have_http_status(:unauthorized)
      expect(EvenementEntrantPa.count).to eq(0)
    end
  end

  describe "T-REJEU-DOUBLON" do
    it "deux fois la même notification -> 1ère applied, 2ème duplicate, une seule ligne évènement" do
      body = payload(identifiant_pa: transmission.identifiant_pa, statut_brut: "SANDBOX_RECEIVED", provider_event_id: "EVT-FIXE")

      post_webhook_pa(raw_body: body, secret: secret)
      expect(JSON.parse(response.body)["resultat"]).to eq("applied")

      post_webhook_pa(raw_body: body, secret: secret)

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["resultat"]).to eq("duplicate")
      expect(EvenementEntrantPa.where(transmission_pa: transmission).count).to eq(1)
      expect(facture.reload.statut).to eq("recue")
    end
  end

  describe "T-COULOIR-UNIQUE" do
    it "produit la même décision que le mode pull (#call) pour un statut équivalent" do
      resultat_pull = PaStatusIngestionService.new(facture: facture).call
      expect(resultat_pull.resultat).to eq("applied")
      expect(resultat_pull.statut_facture_apres).to eq("recue")

      organisation_2 = create(:organisation)
      secret_2 = webhook_secret
      plateforme_2 = create(:plateforme_agreee, organisation: organisation_2, webhook_secret_chiffre: secret_2)
      facture_2 = create(:facture, :deposee, organisation: organisation_2)
      transmission_2 = create(
        :transmission_pa, :depose, organisation: organisation_2, facture: facture_2, plateforme_agreee: plateforme_2
      )

      body = payload(identifiant_pa: transmission_2.identifiant_pa, statut_brut: "SANDBOX_RECEIVED")
      post_webhook_pa(raw_body: body, secret: secret_2)

      expect(JSON.parse(response.body)["resultat"]).to eq(resultat_pull.resultat)
      expect(facture_2.reload.statut).to eq(resultat_pull.statut_facture_apres)
    end
  end

  describe "T-APPEND-ONLY" do
    it "l'événement entrant créé par le webhook reste append-only (aucun update/destroy possible)" do
      body = payload(identifiant_pa: transmission.identifiant_pa, statut_brut: "SANDBOX_RECEIVED")
      post_webhook_pa(raw_body: body, secret: secret)

      evenement = EvenementEntrantPa.last

      expect { evenement.update!(statut_brut: "AUTRE") }.to raise_error(ActiveRecord::RecordInvalid)
      expect { evenement.destroy! }.to raise_error(ActiveRecord::RecordNotDestroyed)
    end
  end

  describe "rattachement et corps invalides (défense en profondeur, sans fuite d'info)" do
    it "identifiant_pa inconnu -> 404 générique, aucune ingestion" do
      body = payload(identifiant_pa: "INCONNU-#{SecureRandom.hex(8)}", statut_brut: "SANDBOX_RECEIVED")

      post_webhook_pa(raw_body: body, secret: secret)

      expect(response).to have_http_status(:not_found)
      expect(EvenementEntrantPa.count).to eq(0)
    end

    it "corps non-JSON -> 400, aucune ingestion" do
      post "/webhooks/pa",
           params: "ceci n'est pas du json",
           headers: {
             "Content-Type" => "application/json",
             "X-Sereno-Signature" => "peu importe",
             "X-Sereno-Signature-Timestamp" => webhook_timestamp
           }

      expect(response).to have_http_status(:bad_request)
      expect(EvenementEntrantPa.count).to eq(0)
    end
  end
end
