# frozen_string_literal: true

class Devis < ApplicationRecord
  self.table_name = "devis"

  # "expire" n'est JAMAIS écrit en base (cf. #expire? plus bas) : il reste
  # dans la liste des statuts valides parce que la contrainte CHECK
  # `check_devis_statut` en base l'autorise déjà (posée au commit fondateur)
  # et que DevisStatutService doit pouvoir raisonner sur l'ensemble complet
  # des statuts nommés dans la roadmap métier, même celui qui est dérivé.
  STATUTS = %w[brouillon envoye accepte refuse expire].freeze

  belongs_to :organisation, inverse_of: :devis
  belongs_to :client, inverse_of: :devis

  has_many :lignes_devis,
           class_name: "LigneDevis",
           foreign_key: :devis_id,
           inverse_of: :devis,
           dependent: :destroy

  has_many :factures,
         class_name: "Facture",
         foreign_key: :devis_id,
         inverse_of: :devis,
         dependent: :restrict_with_exception

  has_many :acomptes,
         class_name: "Acompte",
         foreign_key: :devis_id,
         dependent: :restrict_with_exception

  has_many :evenements_devis,
         class_name: "EvenementDevis",
         foreign_key: :devis_id,
         dependent: :restrict_with_exception

  validates :statut, presence: true, inclusion: { in: STATUTS }

  validates :total_ht, :total_tva, :total_ttc,
            presence: true,
            numericality: { greater_than_or_equal_to: 0 }

  validate :client_appartient_a_la_meme_organisation

  # Réutilise UNIQUEMENT les méthodes de classe pures et gelées de
  # FactureTotalsService (decimal / arrondir_centimes / arrondir_taux) —
  # jamais son instance #call, qui est câblée en dur sur
  # `facture.lignes_facture` et ne peut donc pas prendre un Devis en entrée.
  # Même discipline de calcul qu'une Facture (ventilation TVA par taux,
  # arrondi ROUND_HALF_UP au centime à chaque étape) : c'est ce qui garantit
  # qu'un devis et la facture qui en découlerait affichent le MÊME total au
  # centime, y compris sur les cas d'arrondi limite.
  def recalculer_totaux!
    lignes = lignes_devis.order(:position).to_a

    total_ht = FactureTotalsService.arrondir_centimes(
      lignes.sum { |ligne| FactureTotalsService.decimal(ligne.total_ht) }
    )

    total_tva = FactureTotalsService.arrondir_centimes(
      groupes_tva(lignes).values.sum { |groupe| groupe[:montant_tva] }
    )

    total_ttc = FactureTotalsService.arrondir_centimes(total_ht + total_tva)

    update!(
      total_ht: total_ht,
      total_tva: total_tva,
      total_ttc: total_ttc
    )
  end

  # Dérivé, jamais stocké, jamais de cron : un devis envoyé dont la date de
  # validité est dépassée est "expiré" au sens de l'affichage/API, sans que
  # `statut` change en base — comme resolveDueInfo côté facture (frontend),
  # un statut qui ne ment jamais entre deux lectures.
  def expire?
    statut == "envoye" && date_validite.present? && date_validite < Date.current
  end

  # "Converti" = "ce devis a déjà produit une facture", quel que soit le
  # chemin (DevisConversionService en étage B, OU rattachement manuel d'une
  # facture via devis_id à la création — déjà possible aujourd'hui côté
  # FacturesController). L'idempotence de la conversion se lit donc ICI,
  # jamais sur un champ statut dédié.
  def converti?
    factures.exists?
  end

  def facture_generee
    factures.first
  end

  private

  def groupes_tva(lignes)
    groupes = {}

    lignes.each do |ligne|
      taux = FactureTotalsService.arrondir_taux(ligne.taux_tva)

      groupes[taux] ||= { taux: taux, base_ht: BigDecimal("0") }
      groupes[taux][:base_ht] += FactureTotalsService.decimal(ligne.total_ht)
    end

    groupes.each_value do |groupe|
      groupe[:base_ht] = FactureTotalsService.arrondir_centimes(groupe[:base_ht])
      groupe[:montant_tva] = FactureTotalsService.arrondir_centimes(
        groupe[:base_ht] * groupe[:taux] / BigDecimal("100")
      )
    end

    groupes
  end

  def client_appartient_a_la_meme_organisation
    return if organisation.blank? || client.blank?

    if client.organisation_id != organisation_id
      errors.add(:client, "doit appartenir à la même organisation que le devis")
    end
  end
end
