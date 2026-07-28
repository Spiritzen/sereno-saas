# frozen_string_literal: true

require "fileutils"

# Voie (b) : miroir de FacturXStorageService (SENSIBLE, non modifié) pour
# l'archivage du XML d'un AVOIR. Ferme la dette n°13 : AvoirEmissionService
# appelait jusqu'ici FacturXStorageService par duck-typing (facture: @avoir),
# ce qui écrivait le XML d'un avoir sous storage/<env>/factures/<avoir_id>/
# (dossier codé en dur "factures" dans le service sensible) au lieu de
# storage/<env>/avoirs/<avoir_id>/ — là où AvoirPdfService range déjà
# correctement le PDF du même avoir. Dupliquer ce petit service plutôt que
# paramétrer FacturXStorageService : cohérent avec AvoirXmlService/
# AvoirPdfService/AvoirTotalsService (tous des miroirs dédiés), et ça ne
# touche à aucun fichier SENSIBLE ou GELÉ STRICT pour corriger un simple
# emplacement de rangement.
class AvoirXmlStorageService
  class StorageImpossibleError < StandardError; end

  attr_reader :chemin_archive, :chemin_archive_relatif

  def initialize(avoir:, xml_string: nil)
    @avoir = avoir
    @xml_string = xml_string
  end

  def call
    verifier_avoir!

    xml = @xml_string.presence || AvoirXmlService.new(avoir: @avoir).call

    @chemin_archive_relatif = chemin_relatif
    @chemin_archive = Rails.root.join(@chemin_archive_relatif)

    FileUtils.mkdir_p(@chemin_archive.dirname)
    File.binwrite(@chemin_archive.to_s, xml)

    @chemin_archive
  end

  private

  def verifier_avoir!
    raise StorageImpossibleError, "L'avoir est introuvable" if @avoir.blank?
    raise StorageImpossibleError, "L'avoir doit être émis" unless @avoir.statut == "emise"
    raise StorageImpossibleError, "L'avoir doit avoir un numéro" if @avoir.numero.blank?
  end

  def nom_fichier
    "avoir-#{nom_fichier_securise(@avoir.numero)}.xml"
  end

  def chemin_relatif
    "storage/#{Rails.env}/avoirs/#{@avoir.id}/#{nom_fichier}"
  end

  def nom_fichier_securise(valeur)
    valeur.to_s.gsub(/[^0-9A-Za-z.\-]/, "_")
  end
end
