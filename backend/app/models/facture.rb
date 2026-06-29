# frozen_string_literal: true

class Facture < ApplicationRecord
  STATUTS = %w[
    brouillon
    emise
    deposee
    recue
    mise_a_disposition
    approuvee
    refusee
    en_litige
    encaissee
    archivee
    annulee
  ].freeze

  TYPES_DOCUMENT = %w[facture acompte].freeze
  FORMATS = %w[factur_x ubl cii].freeze

  # Champs de contenu légal et d'archivage bloqués après émission.
  #
  # IMPORTANT :
  # pdf_url et xml_url sont bien bloqués après émission.
  # Ils doivent être renseignés pendant FactureEmissionService, au moment
  # du passage brouillon -> emise, avant que l'immutabilité ne s'applique.
  CHAMPS_IMMUABLES_APRES_EMISSION = %w[
    organisation_id
    client_id
    devis_id
    numero
    type_document
    date_emission
    date_echeance
    total_ht
    total_tva
    total_ttc
    devise
    format
    mentions
    conditions_paiement
    pdf_url
    xml_url
    emise_at
  ].freeze

  belongs_to :organisation
  belongs_to :client

  belongs_to :devis,
             class_name: "Devis",
             foreign_key: :devis_id,
             optional: true

  has_many :lignes_facture,
           class_name: "LigneFacture",
           foreign_key: :facture_id,
           inverse_of: :facture,
           dependent: :destroy

  has_many :acomptes,
           class_name: "Acompte",
           foreign_key: :facture_id,
           dependent: :restrict_with_exception

  has_many :avoirs,
           class_name: "Avoir",
           foreign_key: :facture_id,
           dependent: :restrict_with_exception

  has_many :evenements_facture,
           class_name: "EvenementFacture",
           foreign_key: :facture_id,
           dependent: :restrict_with_exception

  has_many :transmissions_pa,
           class_name: "TransmissionPa",
           foreign_key: :facture_id,
           dependent: :restrict_with_exception

  has_many :paiements, dependent: :restrict_with_exception
  has_many :relances, dependent: :restrict_with_exception

  validates :type_document, presence: true, inclusion: { in: TYPES_DOCUMENT }
  validates :statut, presence: true, inclusion: { in: STATUTS }
  validates :format, presence: true, inclusion: { in: FORMATS }

  validates :devise, presence: true, length: { is: 3 }

  validates :total_ht, :total_tva, :total_ttc, :montant_paye,
            presence: true,
            numericality: { greater_than_or_equal_to: 0 }

  validate :client_appartient_a_la_meme_organisation
  validate :devis_appartient_a_la_meme_organisation
  validate :devis_appartient_au_meme_client
  validate :numero_requis_si_facture_emise
  validate :date_emission_requise_si_facture_emise
  validate :montant_paye_ne_depasse_pas_total_ttc
  validate :date_echeance_apres_date_emission
  validate :empecher_modification_document_emis, on: :update

 def recalculer_totaux!
  totaux = FactureTotalsService.new(facture: self).call

  update!(
    total_ht: totaux.total_ht,
    total_tva: totaux.total_tva,
    total_ttc: totaux.total_ttc
  )
end

  def brouillon?
    statut == "brouillon"
  end

  def emise?
    statut != "brouillon"
  end

  private

  def client_appartient_a_la_meme_organisation
    return if organisation.blank? || client.blank?

    if client.organisation_id != organisation_id
      errors.add(:client, "doit appartenir à la même organisation que la facture")
    end
  end

  def devis_appartient_a_la_meme_organisation
    return if organisation.blank? || devis.blank?

    if devis.organisation_id != organisation_id
      errors.add(:devis, "doit appartenir à la même organisation que la facture")
    end
  end

  def devis_appartient_au_meme_client
    return if client.blank? || devis.blank?

    if devis.client_id != client_id
      errors.add(:devis, "doit appartenir au même client que la facture")
    end
  end

  def numero_requis_si_facture_emise
    return if brouillon?
    return if numero.present?

    errors.add(:numero, "est requis dès que la facture est émise")
  end

  def date_emission_requise_si_facture_emise
    return if brouillon?
    return if date_emission.present? && emise_at.present?

    errors.add(:date_emission, "et emise_at sont requis dès que la facture est émise")
  end

  def montant_paye_ne_depasse_pas_total_ttc
    return if montant_paye.blank? || total_ttc.blank?

    if montant_paye > total_ttc
      errors.add(:montant_paye, "ne peut pas dépasser le total TTC")
    end
  end

  def date_echeance_apres_date_emission
    return if date_emission.blank? || date_echeance.blank?

    if date_echeance < date_emission
      errors.add(:date_echeance, "ne peut pas être avant la date d'émission")
    end
  end

  def empecher_modification_document_emis
    return if statut_in_database == "brouillon"

    champs_bloques_modifies = changed & CHAMPS_IMMUABLES_APRES_EMISSION

    if champs_bloques_modifies.any?
      errors.add(:base, "Une facture émise est immuable pour les champs de contenu")
    end
  end
end
