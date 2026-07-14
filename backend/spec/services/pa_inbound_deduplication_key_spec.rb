# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaInboundDeduplicationKey do
  describe "priorité 1 — provider + provider_event_id" do
    it "produit la même clé pour deux appels identiques" do
      cle_1 = described_class.call(
        provider: "sandbox",
        provider_event_id: "EVT-123",
        identifiant_pa: "SANDBOX-abc",
        statut_brut: "SANDBOX_RECEIVED",
        occurred_at: Time.current,
        payload: { a: 1 }
      )

      cle_2 = described_class.call(
        provider: "sandbox",
        provider_event_id: "EVT-123",
        identifiant_pa: "SANDBOX-abc",
        statut_brut: "SANDBOX_AVAILABLE", # payload différent, provider_event_id identique
        occurred_at: 1.hour.from_now,
        payload: { a: 2 }
      )

      expect(cle_1).to eq(cle_2)
    end

    it "ignore la forme canonique dès qu'un provider_event_id est fourni" do
      cle = described_class.call(
        provider: "sandbox",
        provider_event_id: "EVT-123",
        identifiant_pa: "SANDBOX-abc",
        statut_brut: "SANDBOX_RECEIVED",
        occurred_at: Time.current,
        payload: {}
      )

      expect(cle).to eq("sandbox:event:EVT-123")
    end
  end

  describe "fallback — hash SHA-256 canonique" do
    it "produit la même clé pour un payload structurellement identique mais construit dans un ordre différent" do
      occurred_at = Time.zone.parse("2026-07-14 10:00:00")

      cle_1 = described_class.call(
        provider: "sandbox",
        identifiant_pa: "SANDBOX-abc",
        statut_brut: "SANDBOX_APPROVED",
        occurred_at: occurred_at,
        payload: { statut: "ok", details: { code: 1, libelle: "x" } }
      )

      cle_2 = described_class.call(
        provider: "sandbox",
        identifiant_pa: "SANDBOX-abc",
        statut_brut: "SANDBOX_APPROVED",
        occurred_at: occurred_at,
        payload: { details: { libelle: "x", code: 1 }, statut: "ok" }
      )

      expect(cle_1).to eq(cle_2)
      expect(cle_1).to match(/\A[0-9a-f]{64}\z/)
    end

    it "produit une clé différente si l'occurred_at diffère" do
      cle_1 = described_class.call(
        provider: "sandbox",
        identifiant_pa: "SANDBOX-abc",
        statut_brut: "SANDBOX_APPROVED",
        occurred_at: Time.zone.parse("2026-07-14 10:00:00"),
        payload: {}
      )

      cle_2 = described_class.call(
        provider: "sandbox",
        identifiant_pa: "SANDBOX-abc",
        statut_brut: "SANDBOX_APPROVED",
        occurred_at: Time.zone.parse("2026-07-14 10:00:01"),
        payload: {}
      )

      expect(cle_1).not_to eq(cle_2)
    end

    it "produit une clé différente si le statut_brut diffère" do
      occurred_at = Time.current

      cle_1 = described_class.call(
        provider: "sandbox", identifiant_pa: "SANDBOX-abc",
        statut_brut: "SANDBOX_APPROVED", occurred_at: occurred_at, payload: {}
      )

      cle_2 = described_class.call(
        provider: "sandbox", identifiant_pa: "SANDBOX-abc",
        statut_brut: "SANDBOX_REJECTED", occurred_at: occurred_at, payload: {}
      )

      expect(cle_1).not_to eq(cle_2)
    end
  end
end
