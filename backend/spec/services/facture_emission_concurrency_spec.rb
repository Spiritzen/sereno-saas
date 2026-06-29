# frozen_string_literal: true

require "rails_helper"
require "fileutils"

RSpec.describe "Émission concurrente de factures", type: :service do
  before(:all) do
    @organisation = create(:organisation)
    @client = create(:client, organisation: @organisation)
    @utilisateur = create(:utilisateur, organisation: @organisation)

    @factures = 2.times.map do
      create(:facture, :avec_ligne, organisation: @organisation, client: @client)
    end
  end

  after(:all) do
    FileUtils.rm_rf(Rails.root.join("storage", "factures"))

    EvenementFacture.where(organisation_id: @organisation.id).delete_all
    LigneFacture.where(organisation_id: @organisation.id).delete_all
    Facture.where(organisation_id: @organisation.id).delete_all
    Numerotation.where(organisation_id: @organisation.id).delete_all
    Client.where(organisation_id: @organisation.id).delete_all
    Utilisateur.where(organisation_id: @organisation.id).delete_all
    Organisation.where(id: @organisation.id).delete_all
  end

  it "attribue deux numéros distincts et consécutifs sans trou" do
    barrier = Queue.new

    threads = @factures.map do |facture|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          barrier.pop

          FactureEmissionService.new(
            facture: Facture.find(facture.id),
            utilisateur: Utilisateur.find(@utilisateur.id)
          ).call
        end
      end
    end

    @factures.size.times { barrier << true }

    factures_emises = threads.map(&:value)

    numeros = factures_emises.map(&:numero).sort
    suffixes = numeros.map { |numero| numero.split("-").last.to_i }

    expect(numeros.uniq.size).to eq(2)
    expect(suffixes.max - suffixes.min).to eq(1)
    expect(factures_emises.map(&:statut)).to all(eq("emise"))
  end
end
