# frozen_string_literal: true

# Voie (b) : miroir de FactureTotalsService (GELÉ STRICT — jamais modifié).
# ligne_avoir ne porte QUE total_ht (pas montant_tva/total_ttc par ligne,
# contrairement à ligne_facture) : l'agrégation par taux de TVA ne peut donc
# pas être déléguée telle quelle à l'instance FactureTotalsService, qui lit
# en dur facture.lignes_facture.
#
# Les fonctions PURES de calcul (arrondi centime, arrondi taux, catégorie
# TVA) restent RÉUTILISÉES TELLES QUELLES depuis FactureTotalsService — ce
# sont des méthodes de classe sans dépendance à Facture, donc sûres à
# appeler sans dupliquer leur logique ni toucher au fichier gelé.
class AvoirTotalsService
  Result = Struct.new(:total_ht, :total_tva, :total_ttc, :groupes_tva, keyword_init: true)

  ZERO = BigDecimal("0")
  TVA_DIVISEUR = BigDecimal("100")

  def initialize(avoir:)
    @avoir = avoir
    @lignes = avoir.lignes_avoir.order(:position).to_a
  end

  def call
    groupes = calculer_groupes_tva

    total_ht = FactureTotalsService.arrondir_centimes(
      @lignes.sum { |ligne| FactureTotalsService.decimal(ligne.total_ht) }
    )

    total_tva = FactureTotalsService.arrondir_centimes(
      groupes.values.sum { |groupe| FactureTotalsService.decimal(groupe[:montant_tva]) }
    )

    total_ttc = FactureTotalsService.arrondir_centimes(total_ht + total_tva)

    Result.new(
      total_ht: total_ht,
      total_tva: total_tva,
      total_ttc: total_ttc,
      groupes_tva: groupes
    )
  end

  private

  def calculer_groupes_tva
    groupes = {}

    @lignes.each do |ligne|
      taux = FactureTotalsService.arrondir_taux(ligne.taux_tva)
      categorie = FactureTotalsService.categorie_tva(taux)
      cle = "#{categorie}-#{format('%.2f', taux)}"

      groupes[cle] ||= {
        categorie: categorie,
        taux: taux,
        base_ht: ZERO,
        montant_tva: ZERO
      }

      groupes[cle][:base_ht] += FactureTotalsService.decimal(ligne.total_ht)
    end

    groupes.each_value do |groupe|
      groupe[:base_ht] = FactureTotalsService.arrondir_centimes(groupe[:base_ht])
      groupe[:montant_tva] = FactureTotalsService.arrondir_centimes(
        groupe[:base_ht] * groupe[:taux] / TVA_DIVISEUR
      )
    end

    groupes
  end
end
