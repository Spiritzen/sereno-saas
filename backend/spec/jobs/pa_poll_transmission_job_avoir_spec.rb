# frozen_string_literal: true

require "rails_helper"

# V1.2c — PaPollTransmissionJob sonde désormais aussi les transmissions
# d'avoirs (transmission.document, plus seulement transmission.facture).
# Fichier NEUF : pa_poll_transmission_job_spec.rb (facture) reste inchangé
# et vert (55/55 confirmé lors de la généralisation, aucune modification).
RSpec.describe PaPollTransmissionJob, type: :job do
  let(:organisation) { create(:organisation) }
  let!(:plateforme) { create(:plateforme_agreee, organisation: organisation) }
  let(:avoir) { create(:avoir, :deposee, organisation: organisation) }
  let!(:transmission) do
    create(:transmission_pa, :depose_avoir, organisation: organisation, avoir: avoir, plateforme_agreee: plateforme)
  end

  it "sonde une transmission d'avoir : progression deposee -> recue, un evenement_avoir créé" do
    expect { described_class.perform_now(transmission.id) }.to change(EvenementAvoir, :count).by(1)

    avoir.reload
    expect(avoir.statut).to eq("recue")

    transmission.reload
    expect(transmission.poll_attempts).to eq(1)
    expect(transmission.next_poll_at).to be_present
  end

  it "n'écrit jamais dans evenement_facture pour une transmission d'avoir" do
    compte_facture_avant = EvenementFacture.count

    described_class.perform_now(transmission.id)

    expect(EvenementFacture.count).to eq(compte_facture_avant)
  end

  it "un avoir sans date_echeance (absente du modèle) ne fait pas planter le calcul de limite de polling" do
    expect { described_class.perform_now(transmission.id) }.not_to raise_error
  end

  it "arrête le polling dès que l'avoir atteint un statut terminal (encaissee)" do
    allow(Pa::AdapterFactory).to receive(:for).and_return(
      Pa::SandboxPaAdapter.new(fetch_status_sequence: %w[SANDBOX_APPROVED SANDBOX_PAID])
    )

    described_class.perform_now(transmission.id) # -> approuvee
    transmission.reload
    expect(transmission.polling_stopped_at).to be_nil

    described_class.perform_now(transmission.id) # -> encaissee : doit stopper
    transmission.reload
    avoir.reload

    expect(avoir.statut).to eq("encaissee")
    expect(transmission.polling_stopped_at).to be_present
    expect(transmission.polling_stop_reason).to eq("facture_terminale")
  end
end
