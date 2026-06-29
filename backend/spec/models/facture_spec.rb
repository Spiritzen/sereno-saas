# frozen_string_literal: true

require "rails_helper"

RSpec.describe Facture, type: :model do
  describe "immutabilité après émission" do
    it "interdit la modification des totaux d'une facture émise" do
      facture = create(:facture, :emise)

      expect do
        facture.update!(total_ht: facture.total_ht + 10)
      end.to raise_error(ActiveRecord::RecordInvalid, /Une facture émise est immuable/)
    end

    it "interdit la modification des mentions d'une facture émise" do
      facture = create(:facture, :emise)

      expect do
        facture.update!(mentions: "Modification interdite")
      end.to raise_error(ActiveRecord::RecordInvalid, /Une facture émise est immuable/)
    end

    it "interdit la modification de pdf_url après émission" do
      facture = create(:facture, :emise)

      expect do
        facture.update!(pdf_url: "hack.pdf")
      end.to raise_error(ActiveRecord::RecordInvalid, /Une facture émise est immuable/)
    end

    it "interdit la modification de xml_url après émission" do
      facture = create(:facture, :emise)

      expect do
        facture.update!(xml_url: "hack.xml")
      end.to raise_error(ActiveRecord::RecordInvalid, /Une facture émise est immuable/)
    end

    it "interdit la modification d'une ligne de facture après émission" do
      facture = create(:facture, :emise)
      ligne = facture.lignes_facture.first

      expect(ligne).to be_present

      expect do
        ligne.update!(designation: "Modification interdite")
      end.to raise_error(ActiveRecord::RecordInvalid, /ne peut plus être modifiée après émission/)
    end
  end
end
