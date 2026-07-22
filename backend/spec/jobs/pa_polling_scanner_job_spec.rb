# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaPollingScannerJob, type: :job do
  include ActiveJob::TestHelper

  let(:organisation) { create(:organisation) }
  let!(:plateforme) { create(:plateforme_agreee, organisation: organisation) }
  let(:facture) { create(:facture, :deposee, organisation: organisation) }
  let!(:transmission) do
    create(:transmission_pa, :depose, organisation: organisation, facture: facture, plateforme_agreee: plateforme)
  end

  describe "sélection des transmissions dues" do
    it "enfile une transmission depose dont next_poll_at est NULL (jamais amorcée, pas de backfill en migration)" do
      expect(transmission.next_poll_at).to be_nil

      expect { described_class.perform_now }
        .to have_enqueued_job(PaPollTransmissionJob).with(transmission.id)
    end

    it "enfile une transmission dont next_poll_at est échu" do
      transmission.update!(next_poll_at: 1.minute.ago)

      expect { described_class.perform_now }
        .to have_enqueued_job(PaPollTransmissionJob).with(transmission.id)
    end

    it "n'enfile pas une transmission dont next_poll_at est dans le futur" do
      transmission.update!(next_poll_at: 1.hour.from_now)

      expect { described_class.perform_now }
        .not_to have_enqueued_job(PaPollTransmissionJob).with(transmission.id)
    end

    it "n'enfile pas une transmission pausée" do
      transmission.update!(next_poll_at: 1.minute.ago, polling_paused_at: Time.current)

      expect { described_class.perform_now }
        .not_to have_enqueued_job(PaPollTransmissionJob).with(transmission.id)
    end

    it "n'enfile pas une transmission stoppée" do
      transmission.update!(
        next_poll_at: nil,
        polling_stopped_at: Time.current,
        polling_stop_reason: "facture_terminale"
      )

      expect { described_class.perform_now }
        .not_to have_enqueued_job(PaPollTransmissionJob).with(transmission.id)
    end

    it "n'enfile pas une transmission qui n'est pas depose" do
      transmission.update_columns(statut: "en_attente")

      expect { described_class.perform_now }
        .not_to have_enqueued_job(PaPollTransmissionJob).with(transmission.id)
    end
  end

  describe "10. ANTI DOUBLE-ENFILAGE" do
    it "repousse next_poll_at dès l'enfilage : un 2e scan immédiat n'enfile plus la même transmission" do
      expect(transmission.next_poll_at).to be_nil

      described_class.perform_now
      transmission.reload
      expect(transmission.next_poll_at).to be_present
      expect(transmission.next_poll_at).to be > Time.current

      expect { described_class.perform_now }
        .not_to have_enqueued_job(PaPollTransmissionJob).with(transmission.id)
    end

    # ⚠️ LIMITE DE TEST DOCUMENTÉE : une contention RÉELLE entre deux
    # connexions Postgres simultanées nécessiterait de désactiver les
    # transactions de test (use_transactional_fixtures) pour cet exemple —
    # ce projet n'a pas de gem database_cleaner (et en installer une est
    # hors périmètre B3.1b). Sans cela, deux threads utilisant chacun leur
    # propre connexion ne verraient même pas la ligne créée dans la
    # transaction (non committée) de l'exemple courant : un faux test qui
    # "passerait" pour la mauvaise raison. Plutôt que ça, on prouve BAS
    # NIVEAU que le verrou est bien câblé dans la requête SQL, et on
    # s'appuie sur le test ci-dessus (repousse immédiate) comme garde
    # pratique contre le double-enfilage entre deux passages du scanner.
    it "la sélection utilise bien FOR UPDATE SKIP LOCKED (verrou câblé pour la concurrence réelle)" do
      sql = described_class.new.send(:transmissions_dues).to_sql

      expect(sql).to match(/FOR UPDATE SKIP LOCKED/i)
    end
  end

  describe "9. REPRISE D'UNE TRANSMISSION BLOQUÉE" do
    it "enfile PaRetryStuckSubmissionJob pour une transmission en_attente ancienne, pas un poll" do
      bloquee = create(
        :transmission_pa,
        organisation: organisation,
        facture: create(:facture, :emise, organisation: organisation),
        plateforme_agreee: plateforme,
        statut: "en_attente"
      )
      bloquee.update_columns(created_at: 1.hour.ago)

      expect { described_class.perform_now }
        .to have_enqueued_job(PaRetryStuckSubmissionJob).with(bloquee.id)

      arguments_poll = enqueued_jobs.select { |j| j[:job] == PaPollTransmissionJob }.map { |j| j[:args] }
      expect(arguments_poll).not_to include([ bloquee.id ])
    end

    it "n'enfile pas une transmission en_attente récente (encore dans la fenêtre normale)" do
      recente = create(
        :transmission_pa,
        organisation: organisation,
        facture: create(:facture, :emise, organisation: organisation),
        plateforme_agreee: plateforme,
        statut: "en_attente"
      )

      expect { described_class.perform_now }
        .not_to have_enqueued_job(PaRetryStuckSubmissionJob).with(recente.id)
    end
  end
end
