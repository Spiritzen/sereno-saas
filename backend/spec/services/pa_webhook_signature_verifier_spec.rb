# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaWebhookSignatureVerifier do
  let(:secret) { SecureRandom.hex(32) }
  let(:raw_body) { '{"identifiant_pa":"SANDBOX-abc","statut_brut":"SANDBOX_RECEIVED"}' }
  let(:timestamp) { Time.current.utc.iso8601 }

  def signer(secret:, raw_body:, timestamp:)
    OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{raw_body}")
  end

  it "valide une signature correcte sur un timestamp frais" do
    signature = signer(secret: secret, raw_body: raw_body, timestamp: timestamp)

    resultat = described_class.call(secret: secret, raw_body: raw_body, signature: signature, timestamp: timestamp)

    expect(resultat.valide?).to be(true)
  end

  it "rejette une signature invalide" do
    resultat = described_class.call(secret: secret, raw_body: raw_body, signature: "0" * 64, timestamp: timestamp)

    expect(resultat.valide?).to be(false)
    expect(resultat.motif).to eq(:signature_invalide)
  end

  it "rejette une signature calculée sur un corps différent (preuve du raw body)" do
    signature = signer(secret: secret, raw_body: raw_body, timestamp: timestamp)
    autre_corps = '{"identifiant_pa":"SANDBOX-abc","statut_brut":"SANDBOX_AVAILABLE"}'

    resultat = described_class.call(secret: secret, raw_body: autre_corps, signature: signature, timestamp: timestamp)

    expect(resultat.valide?).to be(false)
    expect(resultat.motif).to eq(:signature_invalide)
  end

  it "rejette un timestamp hors fenêtre (> 5 minutes) même avec une signature valide sur ce timestamp" do
    timestamp_ancien = 10.minutes.ago.utc.iso8601
    signature = signer(secret: secret, raw_body: raw_body, timestamp: timestamp_ancien)

    resultat = described_class.call(secret: secret, raw_body: raw_body, signature: signature, timestamp: timestamp_ancien)

    expect(resultat.valide?).to be(false)
    expect(resultat.motif).to eq(:timestamp_hors_fenetre)
  end

  it "rejette un secret absent" do
    signature = signer(secret: secret, raw_body: raw_body, timestamp: timestamp)

    resultat = described_class.call(secret: nil, raw_body: raw_body, signature: signature, timestamp: timestamp)

    expect(resultat.valide?).to be(false)
    expect(resultat.motif).to eq(:secret_absent)
  end

  it "rejette un timestamp absent" do
    signature = signer(secret: secret, raw_body: raw_body, timestamp: timestamp)

    resultat = described_class.call(secret: secret, raw_body: raw_body, signature: signature, timestamp: nil)

    expect(resultat.valide?).to be(false)
    expect(resultat.motif).to eq(:timestamp_absent)
  end
end
