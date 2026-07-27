# frozen_string_literal: true

require "rails_helper"

# V1.2c — T-COULOIR-UNIQUE-AGNOSTIQUE : le MÊME service, pour un statut
# fournisseur identique, produit la même décision qu'il s'agisse d'une
# facture ou d'un avoir, et journalise dans le bon document. Fichier NEUF,
# ne modifie ni ne remplace les specs facture existantes de ce service
# (couvertes via transmissions_pa_synchroniser_spec.rb / pa_spec.rb).
RSpec.describe "PaStatusIngestionService — agnostique au document (V1.2c)" do
  def stub_adapter(adapter)
    allow(Pa::AdapterFactory).to receive(:for).and_return(adapter)
  end

  let(:organisation) { create(:organisation) }
  let!(:plateforme) { create(:plateforme_agreee, organisation: organisation) }

  it "produit la même décision (applied -> recue) pour une facture et pour un avoir, avec le même statut_brut fournisseur" do
    facture = create(:facture, :deposee, organisation: organisation)
    transmission_facture = create(
      :transmission_pa, :depose, organisation: organisation, facture: facture, plateforme_agreee: plateforme
    )

    avoir = create(:avoir, :deposee, organisation: organisation)
    transmission_avoir = create(
      :transmission_pa, :depose_avoir, organisation: organisation, avoir: avoir, plateforme_agreee: plateforme
    )

    resultat_facture = PaStatusIngestionService.new(facture: facture).call
    resultat_avoir = PaStatusIngestionService.new(document: avoir).call

    expect(resultat_facture.resultat).to eq("applied")
    expect(resultat_avoir.resultat).to eq(resultat_facture.resultat)
    expect(resultat_facture.statut_facture_apres).to eq("recue")
    expect(resultat_avoir.statut_facture_apres).to eq(resultat_facture.statut_facture_apres)

    facture.reload
    avoir.reload
    expect(facture.statut).to eq("recue")
    expect(avoir.statut).to eq("recue")

    expect(transmission_facture.evenements_entrants_pa.count).to eq(1)
    expect(transmission_avoir.evenements_entrants_pa.count).to eq(1)
  end

  it "journalise dans evenement_facture pour une facture, et STRICTEMENT dans evenement_avoir pour un avoir" do
    facture = create(:facture, :deposee, organisation: organisation)
    create(:transmission_pa, :depose, organisation: organisation, facture: facture, plateforme_agreee: plateforme)

    avoir = create(:avoir, :deposee, organisation: organisation)
    create(:transmission_pa, :depose_avoir, organisation: organisation, avoir: avoir, plateforme_agreee: plateforme)

    compte_evenement_facture_avant = EvenementFacture.count
    compte_evenement_avoir_avant = EvenementAvoir.count

    PaStatusIngestionService.new(facture: facture).call

    expect(EvenementFacture.count).to eq(compte_evenement_facture_avant + 1)
    expect(EvenementAvoir.count).to eq(compte_evenement_avoir_avant)

    PaStatusIngestionService.new(document: avoir).call

    expect(EvenementFacture.count).to eq(compte_evenement_facture_avant + 1) # inchangé
    expect(EvenementAvoir.count).to eq(compte_evenement_avoir_avant + 1)
  end

  it "un statut inconnu (unmapped) est traité identiquement pour un avoir : aucune transition, événement conservé" do
    avoir = create(:avoir, :deposee, organisation: organisation)
    create(:transmission_pa, :depose_avoir, organisation: organisation, avoir: avoir, plateforme_agreee: plateforme)

    stub_adapter(Pa::SandboxPaAdapter.new(fetch_status_scenario: :unmapped))

    resultat = PaStatusIngestionService.new(document: avoir).call

    expect(resultat.resultat).to eq("unmapped")
    avoir.reload
    expect(avoir.statut).to eq("deposee")
  end
end
