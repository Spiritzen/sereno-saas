# frozen_string_literal: true

require "rails_helper"

RSpec.describe EvenementAvoir, type: :model do
  describe "append-only" do
    it "interdit la modification d'un événement existant" do
      evenement = create(:evenement_avoir)

      expect(evenement.update(statut: "emise")).to be(false)
    end

    it "interdit la suppression d'un événement existant" do
      evenement = create(:evenement_avoir)

      expect do
        evenement.destroy!
      end.to raise_error(ActiveRecord::RecordNotDestroyed)
    end
  end
end
