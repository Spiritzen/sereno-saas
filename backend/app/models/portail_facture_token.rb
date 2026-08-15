# frozen_string_literal: true

# Portail destinataire (MVP, 13/08/2026) — un lien PUBLIC, TOKENISÉ, PAR
# FACTURE, en LECTURE SEULE. Calqué sur `Session`/`refresh_token_hash`
# (même patron déjà éprouvé par l'auth) : le token BRUT n'est JAMAIS stocké,
# seul son hash SHA256 l'est (colonne unique, indexée) ; la comparaison au
# moment de la résolution passe par ActiveSupport::SecurityUtils.secure_compare
# (timing-safe), jamais un `==` ni une simple recherche par égalité seule.
#
# ⚠️ PRINCIPE DE SÉCURITÉ (cf. §1 execution_portail_destinataire_mvp.txt) :
# ce modèle résout un token vers UNE facture — jamais l'inverse. Aucune
# méthode ici n'accepte un `facture_id`/`id` fourni par un appelant non fiable
# pour retrouver un token : c'est TOUJOURS le token qui pointe vers la
# facture, jamais une facture qu'on questionnerait sur ses tokens à l'aveugle
# depuis un contexte public.
class PortailFactureToken < ApplicationRecord
  # Décision Sébastien (13/08/2026) : validité 12 mois glissants depuis la
  # génération, pas alignée sur l'échéance de la facture (une facture reste
  # consultable/partageable bien après son échéance — c'est même le cas
  # d'usage principal : montrer le reste à payer après relance).
  DUREE_VALIDITE = 12.months

  belongs_to :facture
  belongs_to :organisation

  validates :token_hash, presence: true, uniqueness: true
  validates :expire_at, presence: true

  validate :facture_appartient_a_la_meme_organisation
  validate :empecher_modification_du_hash, on: :update

  class << self
    # Génère un nouveau token pour UNE facture et renvoie le token BRUT —
    # la SEULE fois où il existe en clair dans le process. Jamais journalisé,
    # jamais renvoyé une seconde fois (même discipline que le refresh token
    # de connexion, cf. Api::V1::AuthController#generer_refresh_token).
    def generer!(facture:)
      brut = SecureRandom.hex(64)

      enregistrement = facture.organisation.portail_facture_tokens.create!(
        facture: facture,
        token_hash: hasher(brut),
        expire_at: DUREE_VALIDITE.from_now
      )

      Resultat.new(token: enregistrement, brut: brut)
    end

    # Résout un token BRUT (reçu depuis une URL publique) vers un
    # enregistrement ACTIF, ou nil. Ne lève jamais — un token invalide,
    # inconnu, expiré ou révoqué produit exactement le même nil, pour ne
    # jamais donner à l'appelant un moyen de distinguer ces cas (cf. §1,
    # même discipline que Webhooks::PaController : erreurs génériques).
    def resoudre(token_brut)
      return nil if token_brut.blank?

      hash = hasher(token_brut)
      # find_by (index unique sur token_hash) fait le travail de recherche ;
      # secure_compare est appliqué EN PLUS sur le résultat pour ne jamais
      # dépendre du temps de réponse d'un éventuel futur changement de
      # stratégie de lookup — même geste que le refresh token (auth_controller.rb).
      candidat = find_by(token_hash: hash)
      return nil if candidat.blank?
      return nil unless ActiveSupport::SecurityUtils.secure_compare(candidat.token_hash, hash)
      return nil unless candidat.actif?

      candidat
    end

    # SEULE source de vérité de la base d'URL du frontend (SPA) — le
    # contrôleur owner (générer/révoquer) ET RelanceService (lien paresseux
    # dans le mail de relance) l'appellent tous les deux, jamais une 2e
    # formule ailleurs (fast-follow 15/08/2026, cf. reco_lien_portail_dans_relance).
    #
    # dev/test : ENV["FRONTEND_URL"] si posée, sinon "http://localhost:5173"
    # (défaut Vite du projet, cf. config/initializers/cors.rb).
    # PRODUCTION : ENV["FRONTEND_URL"] OBLIGATOIRE et VALIDE — plus aucun
    # placeholder ("https://app.sereno.fr" supprimé). Absente, mal formée, ou
    # non-https en prod → #{UrlNonConfiguree}, échec BRUYANT et actionnable
    # au moment de construire un lien, plutôt qu'un lien cassé envoyé en
    # silence à un client.
    def frontend_base_url
      brute = ENV["FRONTEND_URL"]

      if Rails.env.production?
        raise Portail::UrlNonConfiguree, MESSAGE_URL_MANQUANTE_PROD if brute.blank?

        normaliser_et_valider!(brute, exiger_https: true, message_erreur: MESSAGE_URL_MANQUANTE_PROD)
      else
        normaliser_et_valider!(
          brute.presence || "http://localhost:5173",
          exiger_https: false,
          message_erreur: "FRONTEND_URL invalide (#{brute.inspect}) : schéma http(s) et host requis"
        )
      end
    end

    # URL ABSOLUE complète du portail pour CE token brut — alignée sur la
    # route SPA `/portail/:token` (frontend/src/App.tsx). Utilisée par le
    # contrôleur owner ET RelanceService.
    def url_publique(token_brut)
      "#{frontend_base_url}/portail/#{token_brut}"
    end

    private

    MESSAGE_URL_MANQUANTE_PROD =
      "FRONTEND_URL manquante ou invalide en production — configurez-la avant " \
      "d'émettre des liens de portail / relances"

    def hasher(token_brut)
      Digest::SHA256.hexdigest(token_brut.to_s)
    end

    # Valide (schéma http(s) + host présents ; https strict si exigé) et
    # NORMALISE (retire un éventuel slash final — cf. #url_publique qui
    # concatène directement "/portail/...", jamais de double-slash).
    def normaliser_et_valider!(url_brute, exiger_https:, message_erreur:)
      uri = URI.parse(url_brute)

      scheme_valide = %w[http https].include?(uri.scheme)
      host_present = uri.host.present?
      https_respecte = !exiger_https || uri.scheme == "https"

      raise Portail::UrlNonConfiguree, message_erreur unless scheme_valide && host_present && https_respecte

      url_brute.sub(%r{/+\z}, "")
    rescue URI::InvalidURIError
      raise Portail::UrlNonConfiguree, message_erreur
    end
  end

  Resultat = Struct.new(:token, :brut, keyword_init: true)

  def expire?
    expire_at <= Time.current
  end

  def revoque?
    revoque_at.present?
  end

  def actif?
    !expire? && !revoque?
  end

  # Immédiat : pas d'attente, pas de fenêtre de grâce (décision Sébastien).
  def revoquer!
    update!(revoque_at: Time.current)
  end

  private

  def facture_appartient_a_la_meme_organisation
    return if facture.blank? || organisation.blank?

    if facture.organisation_id != organisation_id
      errors.add(:facture, "doit appartenir à la même organisation que le token")
    end
  end

  # Append-only sur le HASH uniquement (pas sur toute la ligne, à la
  # différence de Relance#empecher_update) : `revoque_at` DOIT rester
  # modifiable après création — c'est précisément le mécanisme de révocation.
  def empecher_modification_du_hash
    return unless token_hash_changed?

    errors.add(:token_hash, "ne peut jamais être modifié après création")
    throw(:abort)
  end
end
