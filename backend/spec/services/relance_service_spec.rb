# frozen_string_literal: true

require "rails_helper"

RSpec.describe RelanceService, type: :model do
  describe "#envoyer!" do
    it "journalise un échec de livraison plutôt que de le maquiller en succès" do
      facture = create(:facture, :emise, date_echeance: 1.day.ago)
      allow(RelanceMailer).to receive(:rappel).and_raise(Net::SMTPServerBusy, "boom")

      service = described_class.new(organisation: facture.organisation, utilisateur: create(:utilisateur, organisation: facture.organisation))
      relance = service.envoyer!(facture: facture)

      expect(relance).to be_persisted
      expect(relance.statut).to eq("echec")
      expect(relance.envoyee_at).to be_nil
      expect(relance.mode_livraison).to eq("test")
    end

    it "n'envoie aucun mail et ne journalise rien si la facture n'est pas relançable" do
      facture = create(:facture) # brouillon
      utilisateur = create(:utilisateur, organisation: facture.organisation)
      service = described_class.new(organisation: facture.organisation, utilisateur: utilisateur)

      expect {
        expect { service.envoyer!(facture: facture) }.to raise_error(ActiveRecord::RecordInvalid)
      }.not_to change(ActionMailer::Base.deliveries, :count)

      expect(Relance.count).to eq(0)
    end

    it "enregistre mode_livraison = configuration réelle d'ActionMailer sur un envoi réussi" do
      facture = create(:facture, :emise, date_echeance: 1.day.ago)
      utilisateur = create(:utilisateur, organisation: facture.organisation)
      service = described_class.new(organisation: facture.organisation, utilisateur: utilisateur)

      relance = service.envoyer!(facture: facture)

      expect(relance.statut).to eq("envoyee")
      expect(relance.envoyee_at).to be_present
      expect(relance.mode_livraison).to eq(ActionMailer::Base.delivery_method.to_s)
    end
  end

  # v1b (planificateur, 13/08/2026) — extension origine/niveau/date_planifiee.
  describe "#envoyer! — v1b (auto)" do
    it "n'exige pas d'utilisateur (une relance auto n'a pas d'acteur humain)" do
      facture = create(:facture, :emise, date_echeance: 8.days.ago)
      service = described_class.new(organisation: facture.organisation)

      relance = service.envoyer!(facture: facture, origine: "planifie", niveau: 1, date_planifiee: Date.current)

      expect(relance).to be_persisted
      expect(relance.utilisateur_id).to be_nil
      expect(relance.origine).to eq("planifie")
    end

    it "reflète le niveau dans l'objet à partir du palier 2, sans y toucher au palier 1" do
      facture = create(:facture, :emise, date_echeance: 8.days.ago)
      service = described_class.new(organisation: facture.organisation)

      niveau1 = service.envoyer!(facture: facture, origine: "planifie", niveau: 1, date_planifiee: Date.current)
      expect(niveau1.objet).to eq("Rappel de paiement — facture #{facture.numero}")

      niveau3 = service.envoyer!(facture: facture, origine: "planifie", niveau: 3, date_planifiee: Date.current)
      expect(niveau3.objet).to eq("Rappel de paiement (relance 3) — facture #{facture.numero}")
    end

    it "bascule en :file (jamais un navigateur) pour une relance AUTO quand la config réelle est :letter_opener" do
      facture = create(:facture, :emise, date_echeance: 8.days.ago)
      allow(ActionMailer::Base).to receive(:delivery_method).and_return(:letter_opener)
      mail_double = instance_double(ActionMailer::MessageDelivery, deliver_now: true)
      expect(RelanceMailer).to receive(:rappel)
        .with(anything, delivery_method: :file, url_portail: anything)
        .and_return(mail_double)

      service = described_class.new(organisation: facture.organisation)
      relance = service.envoyer!(facture: facture, origine: "planifie", niveau: 1, date_planifiee: Date.current)

      expect(relance.statut).to eq("envoyee")
      expect(relance.mode_livraison).to eq("file")
    end

    it "ne bascule JAMAIS pour le manuel (v1a) — garde l'onglet letter_opener même si la config réelle l'utilise" do
      facture = create(:facture, :emise, date_echeance: 1.day.ago)
      utilisateur = create(:utilisateur, organisation: facture.organisation)
      allow(ActionMailer::Base).to receive(:delivery_method).and_return(:letter_opener)
      mail_double = instance_double(ActionMailer::MessageDelivery, deliver_now: true)
      expect(RelanceMailer).to receive(:rappel)
        .with(anything, delivery_method: nil, url_portail: anything)
        .and_return(mail_double)

      service = described_class.new(organisation: facture.organisation, utilisateur: utilisateur)
      relance = service.envoyer!(facture: facture)

      expect(relance.mode_livraison).to eq("letter_opener")
    end
  end

  # Fast-follow lien-portail (15/08/2026) — point d'injection unique.
  describe "#envoyer! — lien portail (fast-follow 15/08/2026)" do
    it "génère un token de portail à CHAQUE envoi (génération paresseuse)" do
      facture = create(:facture, :emise, date_echeance: 1.day.ago)
      utilisateur = create(:utilisateur, organisation: facture.organisation)
      service = described_class.new(organisation: facture.organisation, utilisateur: utilisateur)

      expect { service.envoyer!(facture: facture) }.to change(PortailFactureToken, :count).by(1)
    end

    it "le corps du mail (texte ET html) contient un lien de portail valide" do
      facture = create(:facture, :emise, date_echeance: 1.day.ago)
      utilisateur = create(:utilisateur, organisation: facture.organisation)
      service = described_class.new(organisation: facture.organisation, utilisateur: utilisateur)

      service.envoyer!(facture: facture)

      mail = ActionMailer::Base.deliveries.last
      lien_attendu = %r{http://localhost:5173/portail/[0-9a-f]{128}}
      expect(mail.text_part.body.to_s).to match(lien_attendu)
      expect(mail.html_part.body.to_s).to match(lien_attendu)
    end

    it "NE révoque JAMAIS les tokens existants — plusieurs liens actifs possibles" do
      facture = create(:facture, :emise, date_echeance: 1.day.ago)
      utilisateur = create(:utilisateur, organisation: facture.organisation)
      service = described_class.new(organisation: facture.organisation, utilisateur: utilisateur)

      service.envoyer!(facture: facture)
      service.envoyer!(facture: facture)

      actifs = facture.portail_facture_tokens.where(revoque_at: nil)
      expect(actifs.count).to eq(2)
    end

    it "manuel ET auto portent chacun le lien (même point d'injection)" do
      facture = create(:facture, :emise, date_echeance: 8.days.ago)

      manuel = described_class.new(
        organisation: facture.organisation,
        utilisateur: create(:utilisateur, organisation: facture.organisation)
      ).envoyer!(facture: facture)

      auto = described_class.new(organisation: facture.organisation)
        .envoyer!(facture: facture, origine: "planifie", niveau: 1, date_planifiee: Date.current)

      expect(facture.portail_facture_tokens.where(revoque_at: nil).count).to eq(2)
      expect(manuel.statut).to eq("envoyee")
      expect(auto.statut).to eq("envoyee")
    end

    it "journalise 'echec' (jamais un crash silencieux) si l'URL du portail ne peut pas être construite" do
      facture = create(:facture, :emise, date_echeance: 1.day.ago)
      utilisateur = create(:utilisateur, organisation: facture.organisation)
      allow(Rails.env).to receive(:production?).and_return(true)
      # FRONTEND_URL volontairement absente (non posée par défaut en test).

      service = described_class.new(organisation: facture.organisation, utilisateur: utilisateur)
      relance = service.envoyer!(facture: facture)

      expect(relance.statut).to eq("echec")
      expect(relance.envoyee_at).to be_nil
    end
  end
end
