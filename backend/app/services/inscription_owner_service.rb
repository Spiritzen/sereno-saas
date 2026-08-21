# frozen_string_literal: true

# R2 (prompt_claude_code_inscription_owner_backend_r2.txt §6) — service
# transactionnel dédié à l'inscription OWNER. Patron directement inspiré de
# Destinataire::InscriptionsController#create (lu comme PATRON uniquement,
# jamais réutilisé ni détourné — pipeline totalement distinct, cf. §1) :
# une seule transaction ActiveRecord, rollback total si l'une des deux
# créations échoue, jamais d'organisation orpheline.
#
# Ce service ne reçoit QUE des attributs déjà bornés par les strong params
# du contrôleur (organisation_attributes/utilisateur_attributes) — il
# n'accepte JAMAIS role, organisation_id ou id depuis l'appelant : le rôle
# "owner" est codé en dur ci-dessous, jamais lu depuis utilisateur_attributes
# même si cette clé y figurait par erreur (elle est explicitement écrasée
# après construction de l'objet).
class InscriptionOwnerService
  MOT_DE_PASSE_LONGUEUR_MIN = 8

  Resultat = Struct.new(:organisation, :utilisateur, keyword_init: true)

  # Erreur UNIQUE pour tout échec attendu (confirmation, longueur, ou
  # validations Organisation/Utilisateur) — le contrôleur la traduit en 422
  # sobre, sans jamais laisser fuiter une exception brute ni un détail SQL.
  class EchecInscription < StandardError
    attr_reader :messages

    def initialize(messages)
      @messages = Array(messages)
      super(@messages.join(", "))
    end
  end

  def self.call(...)
    new(...).call
  end

  def initialize(organisation_attributes:, utilisateur_attributes:, mot_de_passe:, confirmation_mot_de_passe:)
    @organisation_attributes = organisation_attributes
    @utilisateur_attributes = utilisateur_attributes
    @mot_de_passe = mot_de_passe
    @confirmation_mot_de_passe = confirmation_mot_de_passe
  end

  def call
    verifier_mot_de_passe!

    organisation = nil
    utilisateur = nil

    ActiveRecord::Base.transaction do
      organisation = Organisation.create!(@organisation_attributes)

      utilisateur = organisation.utilisateurs.new(@utilisateur_attributes)
      # Rôle IMPOSÉ ici, après construction — jamais lu depuis les params
      # même si utilisateur_attributes contenait une clé :role (les strong
      # params du contrôleur ne la permettent de toute façon jamais, ceci
      # est une seconde barrière, jamais la seule).
      utilisateur.role = "owner"
      utilisateur.actif = true
      utilisateur.definir_mot_de_passe(@mot_de_passe)
      utilisateur.save!
    end

    Resultat.new(organisation: organisation, utilisateur: utilisateur)
  rescue ActiveRecord::RecordInvalid => e
    raise EchecInscription, e.record.errors.full_messages
  rescue ActiveRecord::RecordNotUnique
    # R2.1 (revue corrective, défaut bloquant A) — la validation Rails rend
    # le doublon SÉQUENTIEL propre (RecordInvalid, ci-dessus), mais une
    # course CONCURRENTE peut être gagnée entre la validation et l'écriture :
    # deux requêtes passent toutes deux la validation (aucun doublon vu en
    # lecture), puis l'une des deux perd la course à l'INSERT et PostgreSQL
    # lève RecordNotUnique (index unique organisations.siret OU index
    # fonctionnel utilisateurs sur lower(trim(email)) — cf. migration
    # NormaliserUniciteEmailUtilisateurs). Le bloc `transaction do...end`
    # ci-dessus a DÉJÀ annulé automatiquement toute écriture partielle avant
    # que cette exception ne remonte ici (comportement standard
    # ActiveRecord::Base.transaction) — ce rescue s'exécute donc APRÈS
    # rollback, jamais avant. Message volontairement générique et STATIQUE
    # (jamais e.message, qui embarque le nom de contrainte PostgreSQL et
    # parfois la valeur en conflit) : aucune fuite SQL, aucun nom de
    # contrainte, aucune valeur d'e-mail ou de SIRET dans la réponse.
    raise EchecInscription, [ "Cet e-mail ou ce SIRET est déjà utilisé." ]
  end

  private

  # Vérifiée AVANT l'ouverture de la transaction : ni la confirmation ni la
  # longueur minimale ne dépendent de la base — inutile d'ouvrir/annuler une
  # transaction pour un mot de passe manifestement invalide. definir_mot_de_
  # passe (appelé dans #call) ne peut alors plus lever ArgumentError, la
  # longueur ayant déjà été vérifiée ici avec le même seuil.
  def verifier_mot_de_passe!
    if @mot_de_passe.blank?
      raise EchecInscription, [ "Le mot de passe est obligatoire." ]
    end

    if @mot_de_passe != @confirmation_mot_de_passe
      raise EchecInscription, [ "La confirmation du mot de passe ne correspond pas." ]
    end

    if @mot_de_passe.length < MOT_DE_PASSE_LONGUEUR_MIN
      raise EchecInscription, [ "Le mot de passe doit contenir au moins #{MOT_DE_PASSE_LONGUEUR_MIN} caractères." ]
    end
  end
end
