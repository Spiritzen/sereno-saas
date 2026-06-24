class Numerotation < ApplicationRecord
  TYPES_DOCUMENT = %w[facture avoir acompte devis].freeze

  belongs_to :organisation

  validates :type_document, presence: true, inclusion: { in: TYPES_DOCUMENT }
  validates :annee, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 2000 }
  validates :dernier_numero, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  validates :type_document, uniqueness: {
    scope: [:organisation_id, :annee],
    message: "a déjà une séquence pour cette organisation et cette année"
  }

  before_validation :definir_prefixe_par_defaut, on: :create

  def numero_formate
    "#{prefixe}#{dernier_numero.to_s.rjust(4, "0")}"
  end

  private

  def definir_prefixe_par_defaut
    return if prefixe.present?
    return if type_document.blank? || annee.blank?

    self.prefixe =
      case type_document
      when "facture"
        "FAC-#{annee}-"
      when "avoir"
        "AV-#{annee}-"
      when "acompte"
        "ACP-#{annee}-"
      when "devis"
        "DEV-#{annee}-"
      end
  end
end