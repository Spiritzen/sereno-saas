class PlateformeAgreee < ApplicationRecord
  self.table_name = "plateformes_agreees"
  self.inheritance_column = :_type_disabled

  TYPES = %w[pa chorus_pro].freeze
  STATUTS = %w[connecte deconnecte erreur].freeze

  belongs_to :organisation

  # B5 — chiffrement au repos. Non déterministe (par défaut) : le champ n'est
  # jamais recherché ni comparé (pas de WHERE/unicité dessus), donc rien
  # n'exige le déterminisme, et le non-déterministe est le plus sûr des deux.
  # Clés lues depuis l'ENV, cf. config/initializers/active_record_encryption.rb.
  encrypts :credentials_chiffres

  # R3 (B3.3) — secret de signature webhook PAR ORGANISATION (une seule
  # plateforme_agreee par organisation, cf. validation d'unicité ci-dessous).
  # Champ distinct de credentials_chiffres : nature différente (preuve
  # d'authenticité d'une notification ENTRANTE, jamais utilisé pour un appel
  # SORTANT vers la PA). Jamais recherché/comparé en base -> non déterministe.
  encrypts :webhook_secret_chiffre

  has_many :transmissions_pa,
         class_name: "TransmissionPa",
         foreign_key: :plateforme_agreee_id,
         dependent: :restrict_with_exception

  validates :fournisseur, presence: true, length: { maximum: 50 }
  validates :type, presence: true, inclusion: { in: TYPES }
  validates :api_url, presence: true
  validates :statut, presence: true, inclusion: { in: STATUTS }

  validates :organisation_id, uniqueness: {
    message: "a déjà une plateforme agréée configurée"
  }

  def connectee?
    statut == "connecte"
  end

  def deconnectee?
    statut == "deconnecte"
  end

  def en_erreur?
    statut == "erreur"
  end
end
