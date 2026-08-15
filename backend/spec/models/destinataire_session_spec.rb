# frozen_string_literal: true

require "rails_helper"

RSpec.describe DestinataireSession do
  describe ".generer!" do
    it "crée une session et renvoie le BRUT une seule fois — jamais stocké tel quel" do
      compte = create(:compte_destinataire)

      resultat = described_class.generer!(compte_destinataire: compte)

      expect(resultat.brut).to be_present
      expect(resultat.session).to be_persisted
      expect(resultat.session.token_hash).to eq(Digest::SHA256.hexdigest(resultat.brut))
      expect(resultat.session.token_hash).not_to eq(resultat.brut)
    end

    it "pose expire_at à 30 jours" do
      compte = create(:compte_destinataire)

      resultat = described_class.generer!(compte_destinataire: compte)

      expect(resultat.session.expire_at).to be_within(1.minute).of(30.days.from_now)
    end
  end

  describe "#actif?" do
    it "est actif par défaut" do
      session = create(:destinataire_session, expire_at: 1.day.from_now, revoque_at: nil)

      expect(session.actif?).to be(true)
    end

    it "n'est plus actif une fois expirée" do
      session = create(:destinataire_session, expire_at: 1.minute.ago)

      expect(session.actif?).to be(false)
    end

    it "n'est plus actif une fois révoquée" do
      session = create(:destinataire_session)

      session.revoquer!

      expect(session.actif?).to be(false)
      expect(session.revoque_at).to be_present
    end
  end

  describe "append-only sur le hash" do
    it "interdit de modifier token_hash après création" do
      session = create(:destinataire_session)

      expect(session.update(token_hash: "autre-hash")).to be(false)
    end

    it "autorise la révocation (mise à jour de revoque_at)" do
      session = create(:destinataire_session)

      expect(session.update(revoque_at: Time.current)).to be(true)
    end
  end
end
