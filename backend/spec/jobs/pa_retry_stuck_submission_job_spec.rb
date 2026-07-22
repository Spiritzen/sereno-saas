# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaRetryStuckSubmissionJob, type: :job do
  let(:organisation) { create(:organisation) }
  let!(:plateforme) { create(:plateforme_agreee, organisation: organisation) }
  let(:facture) { create(:facture, :emise, organisation: organisation) }

  it "9. reprend une transmission bloquée en_attente : rejeu idempotent, sans doublon" do
    idempotency_key = SecureRandom.uuid
    transmission = create(
      :transmission_pa,
      organisation: organisation,
      facture: facture,
      plateforme_agreee: plateforme,
      statut: "en_attente",
      idempotency_key: idempotency_key
    )
    transmission.update_columns(created_at: 1.hour.ago)

    compte_transmissions_avant = TransmissionPa.count
    compte_evenements_avant = EvenementFacture.count

    described_class.perform_now(transmission.id)

    expect(TransmissionPa.count).to eq(compte_transmissions_avant)
    expect(EvenementFacture.count).to eq(compte_evenements_avant + 1)

    transmission.reload
    expect(transmission.statut).to eq("depose")
    expect(transmission.identifiant_pa).to be_present

    facture.reload
    expect(facture.statut).to eq("deposee")

    external_id_premier_depot = transmission.identifiant_pa

    # Rejeu : idempotent, aucun doublon de transmission ni d'événement.
    described_class.perform_now(transmission.id)

    expect(TransmissionPa.count).to eq(compte_transmissions_avant)
    expect(EvenementFacture.count).to eq(compte_evenements_avant + 1)
    expect(transmission.reload.identifiant_pa).to eq(external_id_premier_depot)
  end

  it "12. couloir de reprise distinct : appelle TransmissionPaOrchestrationService, pas PaStatusIngestionService" do
    transmission = create(
      :transmission_pa,
      organisation: organisation,
      facture: facture,
      plateforme_agreee: plateforme,
      statut: "en_attente"
    )

    expect(PaStatusIngestionService).not_to receive(:new)
    expect(TransmissionPaOrchestrationService).to receive(:new)
      .with(facture: facture, utilisateur: nil)
      .and_call_original

    described_class.perform_now(transmission.id)
  end

  it "ne fait rien si la transmission n'est plus en_attente (déjà résolue entre l'enfilage et l'exécution)" do
    transmission = create(
      :transmission_pa, :depose,
      organisation: organisation,
      facture: create(:facture, :deposee, organisation: organisation),
      plateforme_agreee: plateforme
    )

    expect(TransmissionPaOrchestrationService).not_to receive(:new)

    described_class.perform_now(transmission.id)
  end

  it "isolation tenant : ne touche jamais aux données d'une autre organisation" do
    autre_organisation = create(:organisation)
    autre_plateforme = create(:plateforme_agreee, organisation: autre_organisation)
    autre_facture = create(:facture, :emise, organisation: autre_organisation)
    autre_transmission = create(
      :transmission_pa,
      organisation: autre_organisation,
      facture: autre_facture,
      plateforme_agreee: autre_plateforme,
      statut: "en_attente"
    )

    transmission = create(
      :transmission_pa,
      organisation: organisation,
      facture: facture,
      plateforme_agreee: plateforme,
      statut: "en_attente"
    )

    described_class.perform_now(transmission.id)

    expect(autre_transmission.reload.statut).to eq("en_attente")
  end
end
