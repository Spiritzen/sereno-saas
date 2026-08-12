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
end
