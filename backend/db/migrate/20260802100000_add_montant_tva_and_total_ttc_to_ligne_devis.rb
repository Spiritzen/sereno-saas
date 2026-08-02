# frozen_string_literal: true

# Étage A devis→facture (V1.3) — aligne ligne_devis sur ligne_facture pour
# pouvoir brancher LigneDevis sur FactureTotalsService.calculer_ligne (GELÉ,
# appelé en lecture) : il faut un montant_tva et un total_ttc PAR LIGNE,
# comme ligne_facture, sinon impossible de stocker le résultat complet du
# calcul gelé. Mêmes contraintes CHECK que ligne_facture (>= 0).
class AddMontantTvaAndTotalTtcToLigneDevis < ActiveRecord::Migration[8.1]
  def change
    add_column :ligne_devis, :montant_tva, :decimal, precision: 12, scale: 2, null: false, default: 0
    add_column :ligne_devis, :total_ttc, :decimal, precision: 12, scale: 2, null: false, default: 0

    add_check_constraint :ligne_devis,
                         "montant_tva >= 0",
                         name: "check_ligne_devis_montant_tva_positive"

    add_check_constraint :ligne_devis,
                         "total_ttc >= 0",
                         name: "check_ligne_devis_total_ttc_positive"
  end
end
