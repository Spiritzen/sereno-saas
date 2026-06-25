# frozen_string_literal: true

class FactureEmissionService
  class EmissionImpossibleError < StandardError
    attr_reader :details

    def initialize(message = "Émission impossible", details: [])
      @details = Array(details)
      @details = [message] if @details.empty?

      super(message)
    end
  end

  def initialize(facture:, utilisateur:)
    @facture = facture
    @utilisateur = utilisateur
    @organisation = facture.organisation
  end

  def call
    ActiveRecord::Base.transaction do
      @facture.lock!

      recalculer_totaux_si_possible!
      verifier_conformite!

      numero = generer_numero!

      @facture.assign_attributes(
        numero: numero,
        statut: "emise",
        date_emission: Date.current,
        emise_at: Time.current
      )

      @facture.save!

      creer_evenement_emission!

      @facture
    end
  end

  private

  def recalculer_totaux_si_possible!
    return unless @facture.respond_to?(:recalculer_totaux!)

    @facture.recalculer_totaux!
    @facture.reload
  end

  def verifier_conformite!
    resultat = FactureConformiteService.new(facture: @facture).call

    return if resultat.conforme?

    raise EmissionImpossibleError.new(
      "La facture n'est pas conforme",
      details: resultat.erreurs
    )
  end

  def generer_numero!
    NumerotationService.new(
      organisation: @organisation,
      type_document: @facture.type_document,
      date: Date.current
    ).generer!
  end

  def creer_evenement_emission!
    EvenementFacture.create!(
      organisation_id: @organisation.id,
      facture_id: @facture.id,
      utilisateur_id: @utilisateur.id,
      statut: @facture.statut,
      source: "interne",
      payload: {
        action: "emission_facture",
        numero: @facture.numero,
        date_emission: @facture.date_emission&.iso8601,
        emise_at: @facture.emise_at&.iso8601
      }
    )
  end
end