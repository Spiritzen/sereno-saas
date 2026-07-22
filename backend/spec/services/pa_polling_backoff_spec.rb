# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaPollingBackoff do
  describe "table normale" do
    it "suit exactement +1min -> +5min -> +15min -> +30min -> +1h -> +3h -> +6h -> +12h -> +24h" do
      expect(described_class.normal_delay(0, jitter: false)).to eq(1.minute)
      expect(described_class.normal_delay(1, jitter: false)).to eq(5.minutes)
      expect(described_class.normal_delay(2, jitter: false)).to eq(15.minutes)
      expect(described_class.normal_delay(3, jitter: false)).to eq(30.minutes)
      expect(described_class.normal_delay(4, jitter: false)).to eq(1.hour)
      expect(described_class.normal_delay(5, jitter: false)).to eq(3.hours)
      expect(described_class.normal_delay(6, jitter: false)).to eq(6.hours)
      expect(described_class.normal_delay(7, jitter: false)).to eq(12.hours)
      expect(described_class.normal_delay(8, jitter: false)).to eq(24.hours)
    end

    it "reste plafonné à 24h au-delà du dernier palier (boucle)" do
      expect(described_class.normal_delay(9, jitter: false)).to eq(24.hours)
      expect(described_class.normal_delay(100, jitter: false)).to eq(24.hours)
    end
  end

  describe "table d'erreur" do
    it "suit exactement +1min -> +5min -> +15min -> +1h -> +6h" do
      expect(described_class.error_delay(0, jitter: false)).to eq(1.minute)
      expect(described_class.error_delay(1, jitter: false)).to eq(5.minutes)
      expect(described_class.error_delay(2, jitter: false)).to eq(15.minutes)
      expect(described_class.error_delay(3, jitter: false)).to eq(1.hour)
      expect(described_class.error_delay(4, jitter: false)).to eq(6.hours)
    end

    it "expose le seuil de pause à 5 erreurs consécutives" do
      expect(described_class::MAX_CONSECUTIVE_ERRORS_BEFORE_PAUSE).to eq(5)
    end
  end

  describe "jitter" do
    it "est neutralisé par défaut en environnement de test (déterminisme des specs)" do
      expect(described_class.default_jitter?).to be(false)
      expect(described_class.normal_delay(0)).to eq(1.minute)
    end

    it "reste disponible explicitement, borné à ±10%" do
      valeurs = Array.new(200) { described_class.normal_delay(0, jitter: true) }

      expect(valeurs).to all(be_between(54.seconds, 66.seconds))
      expect(valeurs.uniq.size).to be > 1
    end
  end
end
