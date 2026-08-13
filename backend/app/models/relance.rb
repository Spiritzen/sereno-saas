class Relance < ApplicationRecord
  # Statuts de FACTURE autorisant une relance : émise/transmise, jamais
  # brouillon, jamais un statut terminal (refusée/en_litige/encaissée/
  # archivée/annulée). Constante de référence de Facture#relancable? — vit
  # ici (et non sur Facture) pour rester au plus près du modèle qui l'a
  # posée en premier (24/06/2026).
  STATUTS_FACTURE_RELANCABLES = %w[
    emise
    deposee
    recue
    mise_a_disposition
    approuvee
  ].freeze
  CANAUX = %w[email courrier].freeze
  STATUTS = %w[planifiee envoyee echec].freeze
  # Origine de la LIGNE elle-même (qui/quoi l'a créée) — à ne jamais
  # confondre avec `statut` ci-dessus (où en est l'ENVOI). Une relance
  # planifiée (v1b) pourra très bien avoir origine: "planifie" ET
  # statut: "planifiee" en même temps : deux axes indépendants. Exécution du
  # 12/08/2026.
  ORIGINES = %w[manuel planifie].freeze
  # "test" en environnement de test (ActionMailer::Base.deliveries, jamais
  # de réseau) — même liste que les valeurs réalistes de
  # config.action_mailer.delivery_method sur ce projet (cf. RelanceService).
  # "file" ajouté en v1b (planificateur) : RelanceEnvoiJob override la
  # livraison en :file (Mail::FileDelivery, natif Rails) quand la config
  # réelle est :letter_opener — un job de fond ne doit jamais tenter
  # d'ouvrir un onglet navigateur (cf. §6 execution_relances_v1b). Reste une
  # valeur RÉELLE de delivery_method, jamais une étiquette inventée.
  MODES_LIVRAISON = %w[letter_opener smtp test file].freeze

  belongs_to :organisation
  belongs_to :facture
  belongs_to :utilisateur, optional: true

  validates :niveau,
            presence: true,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 1,
              less_than_or_equal_to: 3
            }

  validates :canal, presence: true, inclusion: { in: CANAUX }
  validates :statut, presence: true, inclusion: { in: STATUTS }
  validates :origine, presence: true, inclusion: { in: ORIGINES }

  # `date_planifiee` n'a de sens que pour une relance PLANIFIÉE (v1b) — une
  # relance MANUELLE (v1a) est un acte immédiat, sans date de planification.
  # `if: :origine_planifiee?` plutôt que `presence: true` pur (exécution du
  # 12/08/2026, cf. verif_relances_v1a_avant_execution.txt V5 : la
  # contrainte DB seule ne suffisait pas, il fallait aussi assouplir ici).
  validates :date_planifiee, presence: true, if: :origine_planifiee?

  validates :destinataire_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :objet, presence: true

  # `allow_nil` uniquement ici : le service (RelanceService) valide la
  # relance AVANT de tenter l'envoi (donc avant de connaître le mode de
  # livraison réel) — mode_livraison n'est renseigné qu'ensuite, dans le
  # même appel, avant l'unique `save!`. Jamais nil sur une ligne persistée.
  validates :mode_livraison, allow_nil: true, inclusion: { in: MODES_LIVRAISON }

  validate :facture_appartient_a_la_meme_organisation
  validate :utilisateur_appartient_a_la_meme_organisation
  validate :facture_doit_etre_relancable
  validate :envoyee_at_requis_si_envoyee

  validate :empecher_update, on: :update
  before_destroy :empecher_destroy

  # Ordre d'affichage : la relance la plus récente d'abord. `envoyee_at`
  # plutôt que `created_at` — c'est la date de l'ACTE (l'envoi), pas de
  # l'écriture en base (les deux coïncident en v1a, mais pas forcément une
  # fois le planificateur v1b posé).
  scope :recentes, -> { order(envoyee_at: :desc) }
  scope :envoyees, -> { where(statut: "envoyee") }

  # Statut de l'ENVOI (où en est l'acte) — distinct de #origine_planifiee?
  # ci-dessous (QUI a créé la ligne). Existait déjà avant l'ajout d'`origine`
  # : jamais renommé pour ne pas casser cette distinction implicite en
  # écrasant "planifiee" par un second sens.
  def planifiee?
    statut == "planifiee"
  end

  # Origine de la ligne (v1b, planificateur) — nom délibérément DIFFÉRENT de
  # #planifiee? ci-dessus pour ne jamais confondre les deux axes (cf.
  # commentaire de la constante ORIGINES).
  def origine_planifiee?
    origine == "planifie"
  end

  def origine_manuelle?
    origine == "manuel"
  end

  def envoyee?
    statut == "envoyee"
  end

  def echec?
    statut == "echec"
  end

  private

  def facture_appartient_a_la_meme_organisation
    return if organisation.blank? || facture.blank?

    if facture.organisation_id != organisation_id
      errors.add(:facture, "doit appartenir à la même organisation que la relance")
    end
  end

  def utilisateur_appartient_a_la_meme_organisation
    return if organisation.blank? || utilisateur.blank?

    if utilisateur.organisation_id != organisation_id
      errors.add(:utilisateur, "doit appartenir à la même organisation que la relance")
    end
  end

  # Réutilise Facture#relancable? (statut + échéance dépassée + reste à
  # payer > 0, ce dernier dérivé par PaiementSyntheseService) au lieu de
  # dupliquer une 2e formule ici — c'est l'UNIQUE garde-fou d'éligibilité,
  # partagé par le modèle, le service et le serializer.
  def facture_doit_etre_relancable
    return if facture.blank?

    unless facture.relancable?
      errors.add(:facture, "n'est pas éligible à une relance en ce moment")
    end
  end

  def envoyee_at_requis_si_envoyee
    return unless statut == "envoyee"

    if envoyee_at.blank?
      errors.add(:envoyee_at, "est requis quand la relance est envoyée")
    end
  end

  def empecher_update
    errors.add(:base, "Une relance est append-only et ne peut pas être modifiée")
    throw(:abort)
  end

  def empecher_destroy
    errors.add(:base, "Une relance est append-only et ne peut pas être supprimée")
    throw(:abort)
  end
end
