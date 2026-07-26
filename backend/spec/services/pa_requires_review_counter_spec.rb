# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaRequiresReviewCounter, type: :service do
  let(:organisation) { create(:organisation) }
  let(:facture) { create(:facture, :deposee, organisation: organisation) }
  let(:transmission) { create(:transmission_pa, :depose, organisation: organisation, facture: facture) }

  def creer_evenement(resultat:, occurred_at:, transmission_pa: transmission, received_at: occurred_at || Time.current)
    create(
      :evenement_entrant_pa,
      organisation: transmission_pa.organisation,
      transmission_pa: transmission_pa,
      facture: transmission_pa.facture,
      cle_deduplication: SecureRandom.hex(16),
      resultat: resultat,
      occurred_at: occurred_at,
      received_at: received_at
    )
  end

  it "compte une transmission dont le DERNIER événement est requires_review" do
    creer_evenement(resultat: "applied", occurred_at: 2.hours.ago)
    creer_evenement(resultat: "requires_review", occurred_at: 1.hour.ago)

    expect(described_class.call(organisation: organisation)).to eq(1)
  end

  it "1. LE TEST DÉCISIF — REDESCENTE : un applied plus récent fait redescendre le compteur à 0" do
    creer_evenement(resultat: "requires_review", occurred_at: 1.hour.ago)

    expect(described_class.call(organisation: organisation)).to eq(1)

    creer_evenement(resultat: "applied", occurred_at: Time.current)

    expect(described_class.call(organisation: organisation)).to eq(0)
  end

  it "ne compte pas une transmission dont le dernier événement n'est PAS requires_review" do
    creer_evenement(resultat: "stale", occurred_at: Time.current)

    expect(described_class.call(organisation: organisation)).to eq(0)
  end

  it "compte plusieurs transmissions distinctes, chacune pour son propre dernier événement" do
    plateforme = transmission.plateforme_agreee
    autre_facture = create(:facture, :deposee, organisation: organisation)
    autre_transmission = create(
      :transmission_pa, :depose,
      organisation: organisation, facture: autre_facture, plateforme_agreee: plateforme
    )

    creer_evenement(resultat: "requires_review", occurred_at: 1.hour.ago, transmission_pa: transmission)
    creer_evenement(resultat: "requires_review", occurred_at: 1.hour.ago, transmission_pa: autre_transmission)

    expect(described_class.call(organisation: organisation)).to eq(2)
  end

  it "SCOPING : ne compte jamais les requires_review d'une AUTRE organisation" do
    autre_organisation = create(:organisation)
    autre_facture = create(:facture, :deposee, organisation: autre_organisation)
    autre_transmission = create(:transmission_pa, :depose, organisation: autre_organisation, facture: autre_facture)

    creer_evenement(resultat: "requires_review", occurred_at: Time.current, transmission_pa: autre_transmission)

    expect(described_class.call(organisation: organisation)).to eq(0)
  end

  it "utilise received_at en fallback quand occurred_at est absent (même ordre que l'ingestion)" do
    creer_evenement(resultat: "requires_review", occurred_at: nil, transmission_pa: transmission)
      .update_columns(received_at: 2.hours.ago)
    creer_evenement(resultat: "applied", occurred_at: nil, transmission_pa: transmission)
      .update_columns(received_at: 1.hour.ago)

    expect(described_class.call(organisation: organisation)).to eq(0)
  end

  it "APPEND-ONLY : le calcul ne crée ni ne modifie aucune ligne evenement_entrant_pa" do
    creer_evenement(resultat: "requires_review", occurred_at: Time.current)

    compte_avant = EvenementEntrantPa.count

    described_class.call(organisation: organisation)

    expect(EvenementEntrantPa.count).to eq(compte_avant)
  end
end
