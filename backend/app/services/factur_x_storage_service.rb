# frozen_string_literal: true

class FacturXStorageService
  class StorageImpossibleError < StandardError; end

  def initialize(facture:)
    @facture = facture
  end

  def call
    verifier_facture!

    xml = FacturXXmlService.new(facture: @facture).call

    FileUtils.mkdir_p(dossier_facture)
    File.write(chemin_fichier, xml)

    @facture.update!(xml_url: chemin_relatif)

    chemin_fichier
  end

  private

  def verifier_facture!
    raise StorageImpossibleError, "La facture est introuvable" if @facture.blank?
    raise StorageImpossibleError, "La facture doit être émise" unless @facture.statut == "emise"
    raise StorageImpossibleError, "La facture doit avoir un numéro" if @facture.numero.blank?
  end

  def dossier_facture
    Rails.root.join("storage", "factures", @facture.id)
  end

  def nom_fichier
    "factur-x-#{@facture.numero}.xml"
  end

  def chemin_fichier
    dossier_facture.join(nom_fichier)
  end

  def chemin_relatif
    "storage/factures/#{@facture.id}/#{nom_fichier}"
  end
end