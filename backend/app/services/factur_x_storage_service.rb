# frozen_string_literal: true

require "fileutils"

# Chemin cloisonné par Rails.env (storage/<env>/factures/...) : un test ne
# peut plus jamais écrire dans/effacer le storage/development/ réel du poste
# dev. Seul chemin_relatif change ; génération et contenu du XML inchangés.
class FacturXStorageService
  class StorageImpossibleError < StandardError; end

  attr_reader :chemin_archive, :chemin_archive_relatif

    def initialize(facture:, xml_string: nil)
    @facture = facture
    @xml_string = xml_string
  end

  def call
    verifier_facture!

        xml = @xml_string.presence || FacturXXmlService.new(facture: @facture).call

    @chemin_archive_relatif = chemin_relatif
    @chemin_archive = Rails.root.join(@chemin_archive_relatif)

    FileUtils.mkdir_p(@chemin_archive.dirname)
    File.binwrite(@chemin_archive.to_s, xml)

    @chemin_archive
  end

  private

  def verifier_facture!
    raise StorageImpossibleError, "La facture est introuvable" if @facture.blank?
    raise StorageImpossibleError, "La facture doit être émise" unless @facture.statut == "emise"
    raise StorageImpossibleError, "La facture doit avoir un numéro" if @facture.numero.blank?
  end

  def nom_fichier
    "factur-x-#{nom_fichier_securise(@facture.numero)}.xml"
  end

  def chemin_relatif
    "storage/#{Rails.env}/factures/#{@facture.id}/#{nom_fichier}"
  end

  def nom_fichier_securise(valeur)
    valeur.to_s.gsub(/[^0-9A-Za-z.\-]/, "_")
  end
end
