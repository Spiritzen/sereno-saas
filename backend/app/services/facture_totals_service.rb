# frozen_string_literal: true

class FactureTotalsService
  Result = Struct.new(:total_ht, :total_tva, :total_ttc, :groupes_tva, keyword_init: true)

  ZERO = BigDecimal("0")
  TVA_DIVISEUR = BigDecimal("100")

  def self.decimal(valeur)
    BigDecimal(valeur.to_s)
  rescue ArgumentError, TypeError
    ZERO
  end

  def self.arrondir_centimes(valeur)
    decimal(valeur).round(2, BigDecimal::ROUND_HALF_UP)
  end

  def self.arrondir_taux(valeur)
    decimal(valeur).round(2, BigDecimal::ROUND_HALF_UP)
  end

  def self.categorie_tva(taux)
    taux_decimal = decimal(taux)

    return "E" if taux_decimal.zero?

    "S"
  end

  def self.calculer_ligne(quantite:, prix_unitaire_ht:, taux_tva:)
    total_ht = arrondir_centimes(decimal(quantite) * decimal(prix_unitaire_ht))
    taux = arrondir_taux(taux_tva)
    montant_tva = arrondir_centimes(total_ht * taux / TVA_DIVISEUR)
    total_ttc = arrondir_centimes(total_ht + montant_tva)

    {
      total_ht: total_ht,
      montant_tva: montant_tva,
      total_ttc: total_ttc
    }
  end

  def initialize(facture:)
    @facture = facture
    @lignes = facture.lignes_facture.order(:position).to_a
  end

  def call
    groupes = calculer_groupes_tva

    total_ht = self.class.arrondir_centimes(
      @lignes.sum { |ligne| self.class.decimal(ligne.total_ht) }
    )

    total_tva = self.class.arrondir_centimes(
      groupes.values.sum { |groupe| self.class.decimal(groupe[:montant_tva]) }
    )

    total_ttc = self.class.arrondir_centimes(total_ht + total_tva)

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
      taux = self.class.arrondir_taux(ligne.taux_tva)
      categorie = self.class.categorie_tva(taux)
      cle = "#{categorie}-#{format('%.2f', taux)}"

      groupes[cle] ||= {
        categorie: categorie,
        taux: taux,
        base_ht: ZERO,
        montant_tva: ZERO
      }

      groupes[cle][:base_ht] += self.class.decimal(ligne.total_ht)
    end

    groupes.each_value do |groupe|
      groupe[:base_ht] = self.class.arrondir_centimes(groupe[:base_ht])
      groupe[:montant_tva] = self.class.arrondir_centimes(
        groupe[:base_ht] * groupe[:taux] / TVA_DIVISEUR
      )
    end

    groupes
  end
end
