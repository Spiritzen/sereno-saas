# frozen_string_literal: true

require "rails_helper"

RSpec.describe RelanceEnvoiJob, type: :job do
  describe "#perform" do
    it "envoie le mail et journalise une relance AUTO 'envoyee' pour le niveau dû" do
      facture = create(:facture, :emise, date_echeance: 8.days.ago)

      expect { described_class.perform_now(facture.id, 1) }
        .to change(ActionMailer::Base.deliveries, :count).by(1)

      relance = Relance.last
      expect(relance.origine).to eq("planifie")
      expect(relance.niveau).to eq(1)
      expect(relance.statut).to eq("envoyee")
      expect(relance.utilisateur_id).to be_nil
      expect(relance.mode_livraison).to eq(ActionMailer::Base.delivery_method.to_s)
    end

    it "journalise 'echec' (rejouable) si l'envoi échoue, jamais maquillé en succès" do
      facture = create(:facture, :emise, date_echeance: 8.days.ago)
      allow(RelanceMailer).to receive(:rappel).and_raise(Net::SMTPServerBusy, "boom")

      described_class.perform_now(facture.id, 1)

      relance = Relance.last
      expect(relance.statut).to eq("echec")
      expect(relance.envoyee_at).to be_nil
    end

    it "NO-OP silencieux si le niveau n'est plus dû (facture payée entre le scan et l'exécution)" do
      facture = create(:facture, :emise, date_echeance: 8.days.ago)
      create(:paiement, :confirme, facture: facture, organisation: facture.organisation, montant: facture.total_ttc)

      expect { described_class.perform_now(facture.id, 1) }
        .not_to change(ActionMailer::Base.deliveries, :count)

      expect(Relance.count).to eq(0)
    end

    it "NO-OP silencieux si la facture n'existe plus (id invalide)" do
      expect { described_class.perform_now(SecureRandom.uuid, 1) }.not_to raise_error
    end

    it "ne renvoie pas un palier auto déjà 'envoyee' (garde applicative, en plus de la re-vérification cadence)" do
      facture = create(:facture, :emise, date_echeance: 10.days.ago)
      create(:relance, :planifiee,
             facture: facture, organisation: facture.organisation,
             niveau: 1, statut: "envoyee", envoyee_at: Time.current)
      # Force la cadence à re-proposer le niveau 1 malgré tout, pour isoler
      # la garde applicative #deja_envoyee? de la re-vérification cadence
      # normale (qui, seule, aurait déjà avancé au niveau 2).
      allow_any_instance_of(RelanceCadenceService).to receive(:niveau_du).and_return(1)

      expect { described_class.perform_now(facture.id, 1) }
        .not_to change(ActionMailer::Base.deliveries, :count)

      expect(Relance.where(origine: "planifie", statut: "envoyee", niveau: 1).count).to eq(1)
    end

    it "absorbe silencieusement un doublon (RecordNotUnique) sans planter le job — filet DB de dernier recours" do
      facture = create(:facture, :emise, date_echeance: 8.days.ago)
      allow_any_instance_of(RelanceService).to receive(:envoyer!).and_raise(
        ActiveRecord::RecordNotUnique, "boom"
      )

      expect { described_class.perform_now(facture.id, 1) }.not_to raise_error
    end
  end
end
