# frozen_string_literal: true

require "rails_helper"

# V1.2c — T-WEBHOOK-AVOIR : preuve qu'une notification signée pour une
# transmission d'AVOIR se résout et s'ingère correctement via le MÊME
# couloir que pa_spec.rb (B3.3, facture), désormais agnostique au type de
# document. Fichier NEUF : pa_spec.rb (existant, facture) reste inchangé.
RSpec.describe "Webhooks::Pa#recevoir — avoir (V1.2c)", type: :request do
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
  let(:avoir) { create(:avoir, :deposee, organisation: organisation) }
  let!(:transmission) do
    create(:transmission_pa, :depose_avoir, organisation: organisation, avoir: avoir, plateforme_agreee: plateforme)
  end

  it "T-WEBHOOK-AVOIR (décisif) : une notification signée pour une transmission d'avoir est ingérée, applique la transition à l'AVOIR, journalise un evenement_avoir" do
    compte_evenements_facture_avant = EvenementFacture.count

    body = payload(identifiant_pa: transmission.identifiant_pa, statut_brut: "SANDBOX_RECEIVED")

    post_webhook_pa(raw_body: body, secret: secret)

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)["resultat"]).to eq("applied")

    avoir.reload
    expect(avoir.statut).to eq("recue")

    expect(EvenementEntrantPa.where(avoir: avoir).count).to eq(1)
    expect(EvenementAvoir.where(avoir: avoir, statut: "recue").count).to eq(1)
    expect(EvenementFacture.count).to eq(compte_evenements_facture_avant)
  end

  it "signature invalide -> 401, aucune ingestion, l'avoir reste inchangé" do
    body = payload(identifiant_pa: transmission.identifiant_pa, statut_brut: "SANDBOX_RECEIVED")

    post_webhook_pa(raw_body: body, secret: secret, signature: "0" * 64)

    expect(response).to have_http_status(:unauthorized)
    expect(EvenementEntrantPa.count).to eq(0)
    expect(avoir.reload.statut).to eq("deposee")
  end

  it "identifiant_pa d'une autre organisation reste isolé (signature de A ne déverrouille pas l'avoir de B)" do
    organisation_b = create(:organisation)
    secret_b = webhook_secret
    plateforme_b = create(:plateforme_agreee, organisation: organisation_b, webhook_secret_chiffre: secret_b)
    avoir_b = create(:avoir, :deposee, organisation: organisation_b)
    transmission_b = create(
      :transmission_pa, :depose_avoir, organisation: organisation_b, avoir: avoir_b, plateforme_agreee: plateforme_b
    )

    body = payload(identifiant_pa: transmission_b.identifiant_pa, statut_brut: "SANDBOX_RECEIVED")

    # Signé avec le secret de l'organisation A, envoyé pour l'avoir de B.
    post_webhook_pa(raw_body: body, secret: secret)

    expect(response).to have_http_status(:unauthorized)
    expect(avoir_b.reload.statut).to eq("deposee")
  end
end
