# frozen_string_literal: true

require "rails_helper"

RSpec.describe PortailFactureToken do
  # Fast-follow 15/08/2026 — URL partagée, SEULE source de vérité (owner +
  # relance). Isole FRONTEND_URL entre exemples : ni .env ni le processus de
  # test ne la posent par défaut (vérifié), donc `after` suffit à nettoyer.
  describe ".frontend_base_url" do
    after { ENV.delete("FRONTEND_URL") }

    context "hors production (dev/test)" do
      it "utilise FRONTEND_URL si elle est posée" do
        ENV["FRONTEND_URL"] = "http://localhost:4000"

        expect(described_class.frontend_base_url).to eq("http://localhost:4000")
      end

      it "retombe sur http://localhost:5173 (défaut Vite) si FRONTEND_URL est absente" do
        ENV.delete("FRONTEND_URL")

        expect(described_class.frontend_base_url).to eq("http://localhost:5173")
      end

      it "retire un slash final (normalisation)" do
        ENV["FRONTEND_URL"] = "http://localhost:4000/"

        expect(described_class.frontend_base_url).to eq("http://localhost:4000")
      end

      it "lève Portail::UrlNonConfiguree si FRONTEND_URL est posée mais syntaxiquement invalide" do
        ENV["FRONTEND_URL"] = "pas-une-url"

        expect { described_class.frontend_base_url }.to raise_error(Portail::UrlNonConfiguree)
      end
    end

    context "en production" do
      before { allow(Rails.env).to receive(:production?).and_return(true) }

      it "utilise FRONTEND_URL si elle est valide et en https" do
        ENV["FRONTEND_URL"] = "https://app.sereno.fr"

        expect(described_class.frontend_base_url).to eq("https://app.sereno.fr")
      end

      it "retire un slash final en production aussi" do
        ENV["FRONTEND_URL"] = "https://app.sereno.fr/"

        expect(described_class.frontend_base_url).to eq("https://app.sereno.fr")
      end

      it "lève une erreur EXPLICITE si FRONTEND_URL est absente — jamais le placeholder supprimé" do
        ENV.delete("FRONTEND_URL")

        expect { described_class.frontend_base_url }.to raise_error(
          Portail::UrlNonConfiguree, /FRONTEND_URL manquante ou invalide en production/
        )
      end

      it "lève une erreur si FRONTEND_URL n'est pas en https" do
        ENV["FRONTEND_URL"] = "http://app.sereno.fr"

        expect { described_class.frontend_base_url }.to raise_error(Portail::UrlNonConfiguree)
      end

      it "lève une erreur si FRONTEND_URL est syntaxiquement invalide" do
        ENV["FRONTEND_URL"] = "pas-une-url"

        expect { described_class.frontend_base_url }.to raise_error(Portail::UrlNonConfiguree)
      end
    end
  end

  describe ".url_publique" do
    after { ENV.delete("FRONTEND_URL") }

    it "concatène la base et le token brut sous /portail/ — aligné sur la route SPA" do
      ENV["FRONTEND_URL"] = "http://localhost:4000"

      expect(described_class.url_publique("abc123")).to eq("http://localhost:4000/portail/abc123")
    end
  end

  describe ".generer!" do
    it "crée un token et renvoie le BRUT une seule fois — jamais stocké tel quel" do
      facture = create(:facture, :emise, date_echeance: 1.day.ago)

      resultat = described_class.generer!(facture: facture)

      expect(resultat.brut).to be_present
      expect(resultat.token).to be_persisted
      expect(resultat.token.token_hash).to eq(Digest::SHA256.hexdigest(resultat.brut))
      expect(resultat.token.token_hash).not_to eq(resultat.brut)
    end

    it "pose expire_at à 12 mois (décision Sébastien)" do
      facture = create(:facture, :emise, date_echeance: 1.day.ago)

      resultat = described_class.generer!(facture: facture)

      expect(resultat.token.expire_at).to be_within(1.minute).of(12.months.from_now)
    end

    it "rattache le token à l'organisation de la facture" do
      facture = create(:facture, :emise, date_echeance: 1.day.ago)

      resultat = described_class.generer!(facture: facture)

      expect(resultat.token.organisation_id).to eq(facture.organisation_id)
    end
  end

  describe ".resoudre" do
    it "résout un token BRUT valide vers son enregistrement" do
      facture = create(:facture, :emise, date_echeance: 1.day.ago)
      resultat = described_class.generer!(facture: facture)

      expect(described_class.resoudre(resultat.brut)).to eq(resultat.token)
    end

    it "renvoie nil pour un token inconnu (jamais généré)" do
      expect(described_class.resoudre(SecureRandom.hex(64))).to be_nil
    end

    it "renvoie nil pour un token blank" do
      expect(described_class.resoudre(nil)).to be_nil
      expect(described_class.resoudre("")).to be_nil
    end

    it "renvoie nil pour un token expiré" do
      facture = create(:facture, :emise, date_echeance: 1.day.ago)
      resultat = described_class.generer!(facture: facture)
      resultat.token.update_columns(expire_at: 1.minute.ago)

      expect(described_class.resoudre(resultat.brut)).to be_nil
    end

    it "renvoie nil pour un token révoqué" do
      facture = create(:facture, :emise, date_echeance: 1.day.ago)
      resultat = described_class.generer!(facture: facture)
      resultat.token.revoquer!

      expect(described_class.resoudre(resultat.brut)).to be_nil
    end
  end

  describe "#revoquer!" do
    it "pose revoque_at immédiatement — le token n'est plus jamais résolu ensuite" do
      facture = create(:facture, :emise, date_echeance: 1.day.ago)
      resultat = described_class.generer!(facture: facture)

      resultat.token.revoquer!

      expect(resultat.token.revoque_at).to be_present
      expect(resultat.token.actif?).to be(false)
      expect(described_class.resoudre(resultat.brut)).to be_nil
    end
  end

  describe "#actif?" do
    it "est actif par défaut (ni expiré ni révoqué)" do
      token = create(:portail_facture_token, expire_at: 1.month.from_now, revoque_at: nil)

      expect(token.actif?).to be(true)
    end

    it "n'est plus actif une fois la date d'expiration dépassée" do
      token = create(:portail_facture_token, expire_at: 1.minute.ago)

      expect(token.actif?).to be(false)
    end
  end

  describe "cohérence tenant" do
    it "refuse un token dont la facture n'appartient pas à la même organisation" do
      organisation_a = create(:organisation)
      organisation_b = create(:organisation)
      facture = create(:facture, :emise, organisation: organisation_a, date_echeance: 1.day.ago)

      token = build(:portail_facture_token, organisation: organisation_b, facture: facture)

      expect(token).not_to be_valid
      expect(token.errors[:facture]).to be_present
    end
  end

  describe "append-only sur le hash (jamais toute la ligne)" do
    it "interdit de modifier token_hash après création" do
      token = create(:portail_facture_token)

      expect(token.update(token_hash: "autre-hash")).to be(false)
      expect(token.errors[:token_hash]).to be_present
    end

    it "autorise la révocation (mise à jour de revoque_at) — pas un blocage total comme Relance" do
      token = create(:portail_facture_token)

      expect(token.update(revoque_at: Time.current)).to be(true)
    end
  end
end
