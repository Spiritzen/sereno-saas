# frozen_string_literal: true

require "rails_helper"

RSpec.describe EvenementFacture, type: :model do
  describe "append-only" do
    it "interdit la modification d'un événement existant" do
      evenement = create(:evenement_facture)

      expect(evenement.update(statut: "deposee")).to be(false)
    end

    it "interdit la suppression d'un événement existant" do
      evenement = create(:evenement_facture)

      expect do
        evenement.destroy!
      end.to raise_error(ActiveRecord::RecordNotDestroyed)
    end
  end
end
