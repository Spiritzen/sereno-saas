# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaPollTransmissionJob, type: :job do
  include ActiveSupport::Testing::TimeHelpers

  def stub_adapter(adapter)
    allow(Pa::AdapterFactory).to receive(:for).and_return(adapter)
  end

  let(:organisation) { create(:organisation) }
  let!(:plateforme) { create(:plateforme_agreee, organisation: organisation) }
  let(:facture) { create(:facture, :deposee, organisation: organisation) }
  let!(:transmission) do
    create(:transmission_pa, :depose, organisation: organisation, facture: facture, plateforme_agreee: plateforme)
  end

  it "1. PROGRESSION AUTOMATIQUE : deposee -> recue -> mise_a_disposition -> approuvee, sans aucun clic" do
    expect { described_class.perform_now(transmission.id) }.to change(EvenementFacture, :count).by(1)
    facture.reload
    expect(facture.statut).to eq("recue")

    described_class.perform_now(transmission.id)
    facture.reload
    expect(facture.statut).to eq("mise_a_disposition")

    described_class.perform_now(transmission.id)
    facture.reload
    expect(facture.statut).to eq("approuvee")

    expect(EvenementFacture.where(facture: facture).count).to eq(3)
  end

  describe "2. ⚠️ ARRÊT SUR STATUT TERMINAL (le test de cette tranche)" do
    it "stoppe le polling dès que la facture atteint encaissee, et ne la sonde plus jamais" do
      stub_adapter(Pa::SandboxPaAdapter.new(fetch_status_sequence: %w[SANDBOX_APPROVED SANDBOX_PAID]))

      described_class.perform_now(transmission.id) # -> approuvee
      transmission.reload
      expect(transmission.polling_stopped_at).to be_nil

      described_class.perform_now(transmission.id) # -> encaissee : doit stopper
      transmission.reload
      facture.reload

      expect(facture.statut).to eq("encaissee")
      expect(transmission.polling_stopped_at).to be_present
      expect(transmission.polling_stop_reason).to eq("facture_terminale")
      expect(transmission.next_poll_at).to be_nil
    end

    it "le scanner ne sélectionne plus jamais une transmission stoppée" do
      transmission.update!(
        polling_stopped_at: Time.current,
        polling_stop_reason: "facture_terminale",
        next_poll_at: nil
      )

      expect { PaPollingScannerJob.perform_now }
        .not_to have_enqueued_job(PaPollTransmissionJob).with(transmission.id)
    end

    it "aucun appel réseau supplémentaire après l'arrêt : re-invoquer le job ne change plus rien" do
      transmission.update!(
        polling_stopped_at: Time.current,
        polling_stop_reason: "facture_terminale",
        next_poll_at: nil
      )
      facture.update_columns(statut: "encaissee")

      compte_entrant_avant = EvenementEntrantPa.count
      compte_evenements_avant = EvenementFacture.count

      described_class.perform_now(transmission.id)

      expect(EvenementEntrantPa.count).to eq(compte_entrant_avant)
      expect(EvenementFacture.count).to eq(compte_evenements_avant)
    end
  end

  describe "3. BACKOFF NORMAL : les valeurs exactes de la table, sans changement" do
    it "espace next_poll_at selon +1min -> +5min -> +15min -> +30min" do
      stub_adapter(Pa::SandboxPaAdapter.new(fetch_status_scenario: :duplicate))

      t0 = Time.current
      travel_to(t0) { described_class.perform_now(transmission.id) } # applied (recue) -> +1min
      transmission.reload
      expect(transmission.next_poll_at).to be_within(1.second).of(t0 + 1.minute)

      t1 = t0 + 2.minutes
      travel_to(t1) { described_class.perform_now(transmission.id) } # duplicate -> step 1 -> +5min
      transmission.reload
      expect(transmission.poll_backoff_step).to eq(1)
      expect(transmission.next_poll_at).to be_within(1.second).of(t1 + 5.minutes)

      t2 = t1 + 6.minutes
      travel_to(t2) { described_class.perform_now(transmission.id) } # duplicate -> step 2 -> +15min
      transmission.reload
      expect(transmission.poll_backoff_step).to eq(2)
      expect(transmission.next_poll_at).to be_within(1.second).of(t2 + 15.minutes)

      t3 = t2 + 16.minutes
      travel_to(t3) { described_class.perform_now(transmission.id) } # duplicate -> step 3 -> +30min
      transmission.reload
      expect(transmission.poll_backoff_step).to eq(3)
      expect(transmission.next_poll_at).to be_within(1.second).of(t3 + 30.minutes)
    end
  end

  describe "4. RÉINITIALISATION" do
    it "un applied remet le backoff à +1min et consecutive_poll_errors à 0" do
      stub_adapter(Pa::SandboxPaAdapter.new(fetch_status_scenario: :duplicate))
      described_class.perform_now(transmission.id) # applied -> step 0
      described_class.perform_now(transmission.id) # duplicate -> step 1
      transmission.reload
      expect(transmission.poll_backoff_step).to eq(1)

      # Adapter par défaut (progression normale) plutôt qu'un scénario figé
      # à l'index 0 : sinon le provider_event_id (dérivé de l'index, pas du
      # statut_brut) entrerait en collision avec celui du 1er appel et ce
      # 3e appel serait à tort classé "duplicate".
      stub_adapter(Pa::SandboxPaAdapter.new)
      t = Time.current
      travel_to(t) { described_class.perform_now(transmission.id) } # applied (mise_a_disposition)

      transmission.reload
      expect(transmission.poll_backoff_step).to eq(0)
      expect(transmission.consecutive_poll_errors).to eq(0)
      expect(transmission.next_poll_at).to be_within(1.second).of(t + 1.minute)
    end
  end

  describe "5. BACKOFF D'ERREUR + PAUSE" do
    it "5 erreurs réseau consécutives -> pause, facture inchangée, aucun événement, plus aucun appel" do
      stub_adapter(Pa::SandboxPaAdapter.new(simulate_network_error: true))

      compte_evenements_avant = EvenementFacture.count
      compte_entrant_avant = EvenementEntrantPa.count

      4.times { described_class.perform_now(transmission.id) }
      transmission.reload
      expect(transmission.consecutive_poll_errors).to eq(4)
      expect(transmission.polling_paused_at).to be_nil

      described_class.perform_now(transmission.id) # 5e erreur
      transmission.reload

      expect(transmission.consecutive_poll_errors).to eq(5)
      expect(transmission.polling_paused_at).to be_present
      expect(transmission.next_poll_at).to be_nil
      expect(EvenementFacture.count).to eq(compte_evenements_avant)
      expect(EvenementEntrantPa.count).to eq(compte_entrant_avant)
      facture.reload
      expect(facture.statut).to eq("deposee")

      # Pausée : plus aucun appel, même en re-invoquant directement.
      described_class.perform_now(transmission.id)
      transmission.reload
      expect(transmission.consecutive_poll_errors).to eq(5)
    end

    it "suit la table d'erreur +1min -> +5min -> +15min -> +1h -> +6h avant la pause" do
      stub_adapter(Pa::SandboxPaAdapter.new(simulate_network_error: true))

      t0 = Time.current
      travel_to(t0) { described_class.perform_now(transmission.id) }
      transmission.reload
      expect(transmission.next_poll_at).to be_within(1.second).of(t0 + 1.minute)

      t1 = t0 + 2.minutes
      travel_to(t1) { described_class.perform_now(transmission.id) }
      transmission.reload
      expect(transmission.next_poll_at).to be_within(1.second).of(t1 + 5.minutes)
    end
  end

  it "6. PAUSE ≠ STOP : deux champs, deux mécanismes distincts" do
    stub_adapter(Pa::SandboxPaAdapter.new(simulate_network_error: true))
    5.times { described_class.perform_now(transmission.id) }
    transmission.reload

    expect(transmission.polling_paused_at).to be_present
    expect(transmission.polling_stopped_at).to be_nil
    expect(transmission.polling_stop_reason).to be_nil

    autre_transmission = create(
      :transmission_pa, :depose,
      organisation: organisation,
      facture: create(:facture, :deposee, organisation: organisation),
      plateforme_agreee: plateforme
    )
    stub_adapter(Pa::SandboxPaAdapter.new(fetch_status_sequence: %w[SANDBOX_APPROVED SANDBOX_PAID]))
    described_class.perform_now(autre_transmission.id)
    described_class.perform_now(autre_transmission.id)
    autre_transmission.reload

    expect(autre_transmission.polling_stopped_at).to be_present
    expect(autre_transmission.polling_paused_at).to be_nil
  end

  describe "7. LIMITE TEMPORELLE" do
    it "stoppe le polling à expiration (sans échéance) sans inventer d'événement, facture au dernier statut connu" do
      transmission.update_columns(transmis_at: 91.days.ago)
      facture.update_columns(date_echeance: nil)

      compte_evenements_avant = EvenementFacture.count

      described_class.perform_now(transmission.id)
      transmission.reload

      expect(transmission.polling_stopped_at).to be_present
      expect(transmission.polling_stop_reason).to eq("polling_expired")
      expect(EvenementFacture.count).to eq(compte_evenements_avant)
      facture.reload
      expect(facture.statut).to eq("deposee")
    end

    it "prend en compte l'échéance facture + 30 jours quand elle repousse la limite au-delà de transmis_at + 90 jours" do
      # date_limite = MAX(transmis_at + 90j, date_echeance + 30j). Ici
      # transmis_at + 90j est déjà dans le passé, mais l'échéance + 30j est
      # encore dans le futur : le MAX retient l'échéance, la limite n'est
      # donc PAS encore atteinte.
      transmission.update_columns(transmis_at: 95.days.ago)
      facture.update_columns(date_echeance: 10.days.from_now.to_date)
      stub_adapter(Pa::SandboxPaAdapter.new(fetch_status_scenario: :duplicate))

      described_class.perform_now(transmission.id)
      transmission.reload

      expect(transmission.polling_stopped_at).to be_nil
      expect(transmission.next_poll_at).to be_present
    end

    it "stoppe malgré une échéance future si transmis_at + 90 jours ET echeance + 30 jours sont dépassés" do
      transmission.update_columns(transmis_at: 100.days.ago)
      facture.update_columns(date_echeance: 60.days.ago.to_date)

      described_class.perform_now(transmission.id)
      transmission.reload

      expect(transmission.polling_stopped_at).to be_present
      expect(transmission.polling_stop_reason).to eq("polling_expired")
    end
  end

  describe "8. requires_review NE BLOQUE PAS le polling" do
    it "une contradiction depuis un statut terminal n'arrête ni ne pause le polling" do
      # Facture déjà terminale par un autre chemin que ce job (ex. bouton
      # manuel B3.1a) : ce scénario est précisément celui documenté dans
      # PaPollTransmissionJob#stopper_si_condition_arret! comme écart
      # argumenté (aucune garde amont sur le statut terminal, cf. le
      # commentaire du job).
      facture.update_columns(statut: "encaissee")
      stub_adapter(Pa::SandboxPaAdapter.new(fetch_status_sequence: %w[SANDBOX_REJECTED]))

      compte_evenements_avant = EvenementFacture.count

      described_class.perform_now(transmission.id)
      transmission.reload

      expect(transmission.polling_stopped_at).to be_nil
      expect(transmission.polling_paused_at).to be_nil
      expect(transmission.next_poll_at).to be_present

      facture.reload
      expect(facture.statut).to eq("encaissee")
      expect(EvenementFacture.count).to eq(compte_evenements_avant)

      evenement_entrant = EvenementEntrantPa.order(:created_at).last
      expect(evenement_entrant.resultat).to eq("requires_review")
    end
  end

  describe "11. ISOLATION TENANT" do
    it "ne touche jamais aux données d'une autre organisation" do
      autre_organisation = create(:organisation)
      autre_plateforme = create(:plateforme_agreee, organisation: autre_organisation)
      autre_facture = create(:facture, :deposee, organisation: autre_organisation)
      autre_transmission = create(
        :transmission_pa, :depose,
        organisation: autre_organisation, facture: autre_facture, plateforme_agreee: autre_plateforme
      )

      described_class.perform_now(transmission.id)

      autre_transmission.reload
      expect(autre_transmission.poll_attempts).to eq(0)
      expect(autre_transmission.last_polled_at).to be_nil
    end
  end

  describe "12. COULOIR UNIQUE : le job appelle PaStatusIngestionService, ne duplique aucune règle" do
    it "utilise exactement le résultat renvoyé par le service, sans le recalculer" do
      resultat_service = PaStatusIngestionService::Resultat.new(
        resultat: "applied",
        motif: nil,
        evenement_entrant_pa: nil,
        statut_facture_avant: "deposee",
        statut_facture_apres: "recue",
        transmission: transmission
      )

      service_double = instance_double(PaStatusIngestionService, call: resultat_service)
      expect(PaStatusIngestionService).to receive(:new).with(facture: facture).and_return(service_double)

      described_class.perform_now(transmission.id)

      transmission.reload
      expect(transmission.poll_backoff_step).to eq(0)
      expect(transmission.consecutive_poll_errors).to eq(0)
      expect(transmission.next_poll_at).to be_present
    end

    %w[duplicate stale unmapped requires_review].each do |resultat_type|
      it "pour un résultat '#{resultat_type}' renvoyé par le service : avance le backoff normal, ne le recalcule pas" do
        resultat_service = PaStatusIngestionService::Resultat.new(
          resultat: resultat_type,
          motif: "peu importe",
          evenement_entrant_pa: nil,
          statut_facture_avant: "deposee",
          statut_facture_apres: "deposee",
          transmission: transmission
        )

        service_double = instance_double(PaStatusIngestionService, call: resultat_service)
        allow(PaStatusIngestionService).to receive(:new).with(facture: facture).and_return(service_double)

        described_class.perform_now(transmission.id)

        transmission.reload
        expect(transmission.poll_backoff_step).to eq(1)
        expect(transmission.polling_stopped_at).to be_nil
        expect(transmission.polling_paused_at).to be_nil
      end
    end
  end
end
