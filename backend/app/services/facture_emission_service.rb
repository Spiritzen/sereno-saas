# frozen_string_literal: true

class FactureEmissionService
  class EmissionImpossibleError < StandardError; end

  def initialize(facture:, utilisateur:)
    @facture = facture
    @utilisateur = utilisateur
    @organisation = facture.organisation
  end

  def call
    ActiveRecord::Base.transaction do
      @facture.lock!

      verifier_facture_emissible!
      recalculer_totaux_si_possible!

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

  def verifier_facture_emissible!
    raise EmissionImpossibleError, "La facture est introuvable" if @facture.blank?
    raise EmissionImpossibleError, "La facture n'appartient à aucune organisation" if @organisation.blank?
    raise EmissionImpossibleError, "La facture n'est pas en brouillon" unless @facture.brouillon?
    raise EmissionImpossibleError, "La facture possède déjà un numéro" if @facture.numero.present?
    raise EmissionImpossibleError, "La facture doit avoir au moins une ligne" unless @facture.lignes_facture.exists?
    raise EmissionImpossibleError, "Le total TTC doit être supérieur à 0" unless @facture.total_ttc.to_d.positive?
  end

  def recalculer_totaux_si_possible!
    return unless @facture.respond_to?(:recalculer_totaux!)

    @facture.recalculer_totaux!
    @facture.reload
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