# frozen_string_literal: true

require "rails_helper"

RSpec.describe RelanceScannerJob, type: :job do
  include ActiveJob::TestHelper

  let(:organisation) { create(:organisation) }

  describe "sélection des factures dues" do
    it "enfile RelanceEnvoiJob(facture_id, 1) pour une facture émise, impayée, échéance dépassée de 8 jours" do
      facture = create(:facture, :emise, organisation: organisation, date_echeance: 8.days.ago)

      expect { described_class.perform_now }
        .to have_enqueued_job(RelanceEnvoiJob).with(facture.id, 1)
    end

    it "n'enfile rien si le délai du palier n'est pas encore atteint (échéance dépassée de 2 jours < J+7)" do
      create(:facture, :emise, organisation: organisation, date_echeance: 2.days.ago)

      expect { described_class.perform_now }.not_to have_enqueued_job(RelanceEnvoiJob)
    end

    it "n'enfile rien pour une facture non échue" do
      create(:facture, :emise, organisation: organisation, date_echeance: 10.days.from_now)

      expect { described_class.perform_now }.not_to have_enqueued_job(RelanceEnvoiJob)
    end

    it "n'enfile rien pour une facture en brouillon (jamais émise)" do
      create(:facture, organisation: organisation, date_echeance: 8.days.ago)

      expect { described_class.perform_now }.not_to have_enqueued_job(RelanceEnvoiJob)
    end

    it "n'enfile rien pour une facture entièrement payée" do
      facture = create(:facture, :emise, organisation: organisation, date_echeance: 8.days.ago)
      create(:paiement, :confirme, facture: facture, organisation: organisation, montant: facture.total_ttc)

      expect { described_class.perform_now }.not_to have_enqueued_job(RelanceEnvoiJob)
    end

    it "n'enfile rien si le cooldown n'est pas écoulé (rappel manuel très récent)" do
      facture = create(:facture, :emise, organisation: organisation, date_echeance: 8.days.ago)
      create(:relance, facture: facture, organisation: organisation, envoyee_at: 1.day.ago)

      expect { described_class.perform_now }.not_to have_enqueued_job(RelanceEnvoiJob)
    end

    it "enfile le niveau 2 (pas le niveau 1) une fois le niveau 1 auto déjà envoyé et le cooldown écoulé" do
      facture = create(:facture, :emise, organisation: organisation, date_echeance: 16.days.ago)
      create(:relance, :planifiee,
             facture: facture, organisation: organisation,
             niveau: 1, statut: "envoyee", envoyee_at: 9.days.ago)

      expect { described_class.perform_now }
        .to have_enqueued_job(RelanceEnvoiJob).with(facture.id, 2)
    end
  end

  describe "requête SQL (patron PaPollingScannerJob)" do
    it "verrouille FOR UPDATE SKIP LOCKED et borne par BATCH_SIZE" do
      sql = described_class.new.send(:factures_candidates).to_sql

      expect(sql).to match(/FOR UPDATE SKIP LOCKED/i)
      expect(sql).to match(/LIMIT #{RelanceScannerJob::BATCH_SIZE}/)
    end
  end

  describe "isolation transaction / réseau" do
    it "n'effectue aucun envoi de mail lui-même — seulement décide et enfile" do
      create(:facture, :emise, organisation: organisation, date_echeance: 8.days.ago)

      expect { described_class.perform_now }.not_to change(ActionMailer::Base.deliveries, :count)
    end
  end
end
