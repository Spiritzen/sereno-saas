# frozen_string_literal: true

require "rails_helper"

RSpec.describe RelanceMailer, type: :mailer do
  describe "#rappel" do
    let(:facture) { create(:facture, :emise, date_echeance: 1.day.ago) }
    let(:relance) do
      build(
        :relance,
        facture: facture,
        organisation: facture.organisation,
        destinataire_email: "client@destinataire-test.fr",
        objet: "Rappel de paiement — facture #{facture.numero}"
      )
    end
    let(:mail) { described_class.rappel(relance) }

    it "part vers le destinataire_email de la relance, avec l'objet déjà figé" do
      expect(mail.to).to eq([ "client@destinataire-test.fr" ])
      expect(mail.subject).to eq("Rappel de paiement — facture #{facture.numero}")
    end

    it "mentionne le numéro de facture et le montant restant dû dans le corps" do
      reste_a_payer = PaiementSyntheseService.new(facture: facture).call.reste_a_payer
      montant_attendu = reste_a_payer.to_i.to_s

      expect(mail.text_part.body.to_s).to include(facture.numero)
      expect(mail.text_part.body.to_s).to include(montant_attendu)
      expect(mail.html_part.body.to_s).to include(facture.numero)
    end
  end
end
