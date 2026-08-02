class Organisation < ApplicationRecord
  has_many :utilisateurs, dependent: :restrict_with_exception
  has_many :sessions, dependent: :restrict_with_exception
  has_many :abonnements, dependent: :restrict_with_exception
  has_many :clients, dependent: :restrict_with_exception
  has_many :contacts, dependent: :restrict_with_exception
  has_many :taux_tvas, dependent: :restrict_with_exception
  has_many :produits, dependent: :restrict_with_exception
  has_many :devis,
         class_name: "Devis",
         foreign_key: :organisation_id,
         inverse_of: :organisation,
         dependent: :restrict_with_exception
  has_many :lignes_devis,
         class_name: "LigneDevis",
         foreign_key: :organisation_id,
         dependent: :restrict_with_exception
  has_many :evenements_devis,
         class_name: "EvenementDevis",
         foreign_key: :organisation_id,
         dependent: :restrict_with_exception
  has_many :factures, dependent: :restrict_with_exception
  has_many :lignes_facture,
         class_name: "LigneFacture",
         foreign_key: :organisation_id,
         dependent: :restrict_with_exception
  has_many :acomptes, dependent: :restrict_with_exception
  has_many :avoirs, dependent: :restrict_with_exception
  has_many :lignes_avoir,
         class_name: "LigneAvoir",
         foreign_key: :organisation_id,
         dependent: :restrict_with_exception
  has_many :evenements_facture,
         class_name: "EvenementFacture",
         foreign_key: :organisation_id,
         dependent: :restrict_with_exception
  has_many :numerotations, dependent: :restrict_with_exception
  has_one :plateforme_agreee,
        class_name: "PlateformeAgreee",
        foreign_key: :organisation_id,
        dependent: :restrict_with_exception
  has_many :transmissions_pa,
         class_name: "TransmissionPa",
         foreign_key: :organisation_id,
         dependent: :restrict_with_exception
  has_many :e_reportings,
         class_name: "EReporting",
         foreign_key: :organisation_id,
         dependent: :restrict_with_exception
  has_many :paiements, dependent: :restrict_with_exception
  has_many :relances, dependent: :restrict_with_exception

  validates :raison_sociale, presence: true
  validates :siret, presence: true, uniqueness: true, length: { is: 14 },
                     format: { with: /\A\d{14}\z/, message: "doit être composé de 14 chiffres" }
  validates :regime_tva, presence: true
  validates :adresse_ligne1, presence: true
  validates :code_postal, presence: true
  validates :ville, presence: true
  validates :pays, presence: true, length: { is: 2 }
  validates :email, presence: true

  validates :regime_tva, inclusion: {
    in: %w[franchise reel_simplifie reel_normal]
  }
end
