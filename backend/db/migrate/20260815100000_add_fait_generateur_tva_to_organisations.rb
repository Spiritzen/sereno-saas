class AddFaitGenerateurTvaToOrganisations < ActiveRecord::Migration[8.1]
  # Export FEC (MVP, 15/08/2026) — porte le régime DÉCLARÉ (pour l'étiquette
  # d'honnêteté et une future version fine du traitement TVA), mais
  # N'INFLUENCE PAS encore les écritures produites : le MVP écrit TOUJOURS la
  # TVA à la date de facture (cf. FecExportService). Défaut "encaissements"
  # (cas le plus fréquent des prestations de services) — décision Sébastien,
  # pas d'UI pour le changer dans ce MVP (fast-follow, consigné en dette).
  def change
    add_column :organisations, :fait_generateur_tva, :string, null: false, default: "encaissements"

    add_check_constraint :organisations,
                          "fait_generateur_tva IN ('debits', 'encaissements')",
                          name: "check_organisations_fait_generateur_tva"
  end
end
