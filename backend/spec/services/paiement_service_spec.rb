# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaiementService, type: :service do
  let(:organisation) { create(:organisation) }
  let(:utilisateur) { create(:utilisateur, organisation: organisation) }
  let(:facture) { create(:facture, :emise, organisation: organisation) }
  let(:service) { described_class.new(organisation: organisation, utilisateur: utilisateur) }

  describe "#enregistrer!" do
    it "crée le paiement ET son événement dans la même transaction" do
      paiement = service.enregistrer!(
        facture: facture,
        attributs: { montant: 50, methode_code: "58", date_encaissement: Date.current }
      )

      expect(paiement).to be_persisted
      expect(paiement.statut).to eq("brouillon")

      evenement = EvenementPaiement.find_by(paiement_id: paiement.id)
      expect(evenement).to be_present
      expect(evenement.statut).to eq("brouillon")
      expect(evenement.source).to eq("interne")
    end

    it "peut enregistrer directement un paiement confirmé (sans étape brouillon)" do
      paiement = service.enregistrer!(
        facture: facture,
        attributs: { montant: 50, methode_code: "58", date_encaissement: Date.current },
        statut: "confirme"
      )

      expect(paiement.statut).to eq("confirme")
      expect(EvenementPaiement.find_by(paiement_id: paiement.id).statut).to eq("confirme")
    end

    it "ne crée ni paiement ni événement si la facture n'est pas éligible" do
      facture_brouillon = create(:facture, organisation: organisation)

      expect do
        begin
          service.enregistrer!(
            facture: facture_brouillon,
            attributs: { montant: 50, methode_code: "58", date_encaissement: Date.current }
          )
        rescue ActiveRecord::RecordInvalid
          nil
        end
      end.not_to change(Paiement, :count)

      expect(EvenementPaiement.count).to eq(0)
    end

    it "n'expose jamais l'email de l'acteur dans le payload de l'événement" do
      paiement = service.enregistrer!(
        facture: facture,
        attributs: { montant: 50, methode_code: "58", date_encaissement: Date.current }
      )

      evenement = EvenementPaiement.find_by(paiement_id: paiement.id)
      expect(evenement.payload.to_s).not_to include(utilisateur.email)
    end
  end

  describe "#confirmer!" do
    it "transitionne vers confirme et journalise un événement" do
      paiement = service.enregistrer!(
        facture: facture,
        attributs: { montant: 50, methode_code: "58", date_encaissement: Date.current }
      )

      service.confirmer!(paiement: paiement)

      expect(paiement.reload.statut).to eq("confirme")
      expect(EvenementPaiement.where(paiement_id: paiement.id).pluck(:statut)).to eq(%w[brouillon confirme])
    end
  end

  describe "#annuler!" do
    it "transitionne un paiement confirmé vers annule et journalise un événement" do
      paiement = service.enregistrer!(
        facture: facture,
        attributs: { montant: 50, methode_code: "58", date_encaissement: Date.current },
        statut: "confirme"
      )

      service.annuler!(paiement: paiement)

      expect(paiement.reload.statut).to eq("annule")
      expect(EvenementPaiement.where(paiement_id: paiement.id).pluck(:statut)).to eq(%w[confirme annule])
    end

    it "refuse d'annuler un paiement encore brouillon (transition non autorisée)" do
      paiement = service.enregistrer!(
        facture: facture,
        attributs: { montant: 50, methode_code: "58", date_encaissement: Date.current }
      )

      expect { service.annuler!(paiement: paiement) }.to raise_error(ActiveRecord::RecordInvalid)
      expect(EvenementPaiement.where(paiement_id: paiement.id).count).to eq(1)
    end
  end
end
