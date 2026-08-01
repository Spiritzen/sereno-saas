# frozen_string_literal: true

# Registre local des encaissements (v1 = suivi seul, aucune transmission).
# Append-only après confirmation — miroir du patron Avoir (voie b) : un
# paiement brouillon est librement éditable et destructible (il n'a encore
# aucun effet réel) ; un paiement confirmé devient immuable pour ses champs
# de contenu et ne peut plus être détruit ; l'annulation d'un paiement réel
# est un changement de STATUT (confirme -> annule), jamais un destroy.
#
# ⚠️ Ce modèle N'ÉCRIT JAMAIS facture.statut ni facture.montant_paye — c'est
# l'anti-pattern exact de l'ancien squelette mort (retiré le 31/07/2026, voir
# la migration 20260731100000). Le "payé" / "reste à payer" se DÉRIVENT
# (PaiementSyntheseService), ils ne se stockent jamais sur la facture. Le
# statut "encaissee" de Facture/Avoir appartient à la machine de transmission
# PA (confirmation de la plateforme acheteur) — strictement indépendant de ce
# registre local, jamais posé par ce modèle.
class Paiement < ApplicationRecord
  STATUTS = %w[brouillon confirme annule].freeze

  TRANSITIONS_AUTORISEES = {
    "brouillon" => %w[confirme],
    "confirme" => %w[annule],
    "annule" => []
  }.freeze

  # Nomenclature UNTDID 4461 (BT-81 / PaymentMeansTypeCode). Le "virement" est
  # aligné sur le code déjà émis par le moteur GELÉ (factur_x_xml_service.rb,
  # PAYMENT_MEANS_TRANSFER_CODE = "58", virement SEPA) plutôt que sur le code
  # générique "30" (virement non spécifié) : un même moyen de paiement doit
  # porter le même code partout dans l'application. Décision à confirmer par
  # Sébastien (voir rapport de ce sprint).
  MOYENS = {
    "10" => "Espèces",
    "20" => "Chèque",
    "48" => "Carte bancaire",
    "58" => "Virement SEPA",
    "59" => "Prélèvement SEPA"
  }.freeze

  CHAMPS_IMMUABLES_APRES_CONFIRMATION = %w[
    organisation_id
    facture_id
    montant
    methode_code
    date_encaissement
    reference
  ].freeze

  belongs_to :organisation
  belongs_to :facture

  has_many :evenements_paiement,
           class_name: "EvenementPaiement",
           foreign_key: :paiement_id,
           dependent: :restrict_with_exception

  validates :statut, presence: true, inclusion: { in: STATUTS }
  validates :montant, presence: true, numericality: { greater_than: 0 }
  validates :methode_code, presence: true, inclusion: { in: MOYENS.keys }
  validates :date_encaissement, presence: true
  validates :reference, length: { maximum: 100 }, allow_blank: true

  validate :facture_appartient_a_la_meme_organisation
  validate :facture_eligible_au_paiement, on: :create
  validate :transition_de_statut_autorisee, on: :update
  validate :empecher_modification_contenu_apres_confirmation, on: :update

  before_destroy :empecher_destruction_paiement_non_brouillon

  def brouillon?
    statut == "brouillon"
  end

  def confirme?
    statut == "confirme"
  end

  def annule?
    statut == "annule"
  end

  def libelle_moyen
    MOYENS.fetch(methode_code, methode_code)
  end

  private

  def facture_appartient_a_la_meme_organisation
    return if organisation.blank? || facture.blank?

    if facture.organisation_id != organisation_id
      errors.add(:facture, "doit appartenir à la même organisation que le paiement")
    end
  end

  # Éligibilité définie explicitement (facture émise ET non annulée) — ne
  # reprend PAS la liste erronée du mort, qui mélangeait les statuts de la
  # machine de transmission PA avec la notion de payabilité.
  def facture_eligible_au_paiement
    return if facture.blank?

    if facture.brouillon? || facture.statut == "annulee"
      errors.add(:facture, "doit être émise et non annulée pour recevoir un paiement")
    end
  end

  # Un brouillon peut être resauvegardé librement TANT QU'il reste brouillon
  # (édition de contenu, pas une transition). Dès qu'il n'est plus brouillon,
  # toute sauvegarde doit être une transition explicitement autorisée par la
  # table — y compris re-confirmer un paiement déjà confirmé (rejeté : ce
  # n'est pas dans TRANSITIONS_AUTORISEES["confirme"]), pas seulement les
  # changements de valeur détectés par Rails (statut_changed?).
  def transition_de_statut_autorisee
    return if statut_in_database == "brouillon" && !statut_changed?

    autorisees = TRANSITIONS_AUTORISEES.fetch(statut_in_database, [])

    unless autorisees.include?(statut)
      errors.add(:statut, "transition de #{statut_in_database} vers #{statut} non autorisée")
    end
  end

  def empecher_modification_contenu_apres_confirmation
    return if statut_in_database == "brouillon"

    champs_bloques_modifies = changed & CHAMPS_IMMUABLES_APRES_CONFIRMATION

    if champs_bloques_modifies.any?
      errors.add(:base, "Un paiement confirmé ou annulé est immuable pour ses champs de contenu")
    end
  end

  def empecher_destruction_paiement_non_brouillon
    return if statut_in_database == "brouillon"

    errors.add(:base, "Un paiement confirmé ou annulé ne peut pas être détruit")
    throw(:abort)
  end
end
