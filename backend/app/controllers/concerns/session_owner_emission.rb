# frozen_string_literal: true

require "digest"

# R2 (prompt_claude_code_inscription_owner_backend_r2.txt §1/§8) —
# extraction MINIMALE, SANS changement de comportement, des primitives de
# cookies OWNER déjà éprouvées par Api::V1::AuthController (login/refresh/
# logout). Un déplacement de code, pas une réécriture : chaque méthode
# ci-dessous est reprise à l'identique.
#
# Pourquoi cette extraction : Api::V1::InscriptionsController doit pouvoir
# émettre une session IMMÉDIATEMENT après inscription (stratégie A du §8 —
# « si une session peut être émise en réutilisant réellement la mécanique
# OWNER existante sans duplication fragile, elle doit l'être »). Ces
# méthodes étaient PRIVÉES sur AuthController — inaccessibles depuis un
# contrôleur frère sans extraction. Interdiction explicite du prompt :
# « ne jamais créer une deuxième implémentation divergente des cookies
# OWNER » — d'où ce concern PARTAGÉ plutôt qu'une copie.
#
# Preuve de non-régression : auth_security_spec.rb repassé intégralement au
# vert après cette extraction, sans aucune modification de ce fichier de
# spec (cf. rapport R2).
module SessionOwnerEmission
  extend ActiveSupport::Concern

  private

  # Ouvre une Session OWNER et pose les cookies — utilisée par
  # AuthController#login/#refresh (via les méthodes ci-dessous, inchangées)
  # ET par InscriptionsController#create (nouveau) pour l'émission
  # immédiate après inscription.
  def emettre_session_owner!(utilisateur:, organisation:)
    refresh_token = generer_refresh_token

    session = utilisateur.sessions.create!(
      organisation: organisation,
      refresh_token_hash: hash_refresh_token(refresh_token),
      user_agent: request.user_agent,
      ip_adresse: request.remote_ip,
      expire_at: AuthTokenService::REFRESH_TOKEN_EXPIRATION.from_now
    )

    access_token = AuthTokenService.encode(
      utilisateur: utilisateur,
      organisation: organisation,
      session: session
    )

    poser_cookies_authentification(access_token: access_token, refresh_token: refresh_token)

    session
  end

  def generer_refresh_token
    SecureRandom.hex(64)
  end

  def hash_refresh_token(refresh_token)
    Digest::SHA256.hexdigest(refresh_token.to_s)
  end

  def poser_cookies_authentification(access_token:, refresh_token:)
    cookies[:access_token] = {
      value: access_token,
      httponly: true,
      secure: cookie_secure?,
      same_site: cookie_same_site,
      expires: AuthTokenService::ACCESS_TOKEN_EXPIRATION.from_now
    }

    cookies[:refresh_token] = {
      value: refresh_token,
      httponly: true,
      secure: cookie_secure?,
      same_site: cookie_same_site,
      expires: AuthTokenService::REFRESH_TOKEN_EXPIRATION.from_now
    }
  end

  def supprimer_cookies_authentification
    [ :access_token, :refresh_token ].each do |nom_cookie|
      cookies.delete(
        nom_cookie,
        httponly: true,
        secure: cookie_secure?,
        same_site: cookie_same_site
      )
    end
  end

  def cookie_secure?
    Rails.env.production? || ActiveModel::Type::Boolean.new.cast(ENV.fetch("AUTH_COOKIE_SECURE", false))
  end

  def cookie_same_site
    valeur = ENV.fetch("AUTH_COOKIE_SAME_SITE", Rails.env.production? ? "none" : "lax").downcase

    same_site = valeur.in?(%w[lax strict none]) ? valeur.to_sym : :lax

    return :lax if same_site == :none && !cookie_secure?

    same_site
  end
end
