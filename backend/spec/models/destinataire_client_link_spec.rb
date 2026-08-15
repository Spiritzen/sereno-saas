# frozen_string_literal: true

require "rails_helper"

RSpec.describe DestinataireClientLink do
  describe "unicité (compte, client)" do
    it "refuse un second lien pour le même couple (compte, client)" do
      organisation = create(:organisation)
      compte = create(:compte_destinataire)
      client = create(:client, organisation: organisation)
      facture1 = create(:facture, :emise, organisation: organisation, client: client)
      facture2 = create(:facture, :emise, organisation: organisation, client: client)

      create(:destinataire_client_link, compte_destinataire: compte, client: client, facture_preuve: facture1)
      doublon = build(:destinataire_client_link, compte_destinataire: compte, client: client, facture_preuve: facture2)

      expect(doublon).not_to be_valid
      expect(doublon.errors[:compte_destinataire_id]).to be_present
    end

    it "autorise le même client lié à DEUX comptes différents (cas normal)" do
      organisation = create(:organisation)
      client = create(:client, organisation: organisation)
      facture = create(:facture, :emise, organisation: organisation, client: client)

      create(:destinataire_client_link, compte_destinataire: create(:compte_destinataire), client: client, facture_preuve: facture)
      autre = build(:destinataire_client_link, compte_destinataire: create(:compte_destinataire), client: client, facture_preuve: facture)

      expect(autre).to be_valid
    end
  end

  describe "cree_via" do
    it "n'accepte que 'lien_portail' (seule origine existante — suggestion e-mail hors périmètre)" do
      lien = build(:destinataire_client_link, cree_via: "email")

      expect(lien).not_to be_valid
      expect(lien.errors[:cree_via]).to be_present
    end
  end

  describe "cohérence de la preuve" do
    it "refuse une facture_preuve qui n'appartient pas au client du lien" do
      organisation = create(:organisation)
      client = create(:client, organisation: organisation)
      autre_client = create(:client, organisation: organisation)
      facture_autre_client = create(:facture, :emise, organisation: organisation, client: autre_client)

      lien = build(:destinataire_client_link, client: client, facture_preuve: facture_autre_client)

      expect(lien).not_to be_valid
      expect(lien.errors[:facture_preuve]).to be_present
    end
  end
end
