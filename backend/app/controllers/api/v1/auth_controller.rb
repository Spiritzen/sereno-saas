require "digest"

class Api::V1::AuthController < Api::V1::BaseController
  skip_before_action :authenticate_request!, only: [:login]

  def login
    utilisateur = Utilisateur.includes(:organisation).find_by(
      email: login_params[:email].to_s.strip.downcase
    )

    unless utilisateur&.actif? && utilisateur.mot_de_passe_valide?(login_params[:password])
      return render json: { error: "Email ou mot de passe invalide" }, status: :unauthorized
    end

    session = utilisateur.sessions.create!(
      organisation: utilisateur.organisation,
      refresh_token_hash: Digest::SHA256.hexdigest(SecureRandom.hex(64)),
      user_agent: request.user_agent,
      ip_adresse: request.remote_ip,
      expire_at: AuthTokenService::REFRESH_TOKEN_EXPIRATION.from_now
    )

    access_token = AuthTokenService.encode(
      utilisateur: utilisateur,
      organisation: utilisateur.organisation,
      session: session
    )

    cookies[:access_token] = {
      value: access_token,
      httponly: true,
      secure: Rails.env.production?,
      same_site: :lax,
      expires: AuthTokenService::ACCESS_TOKEN_EXPIRATION.from_now
    }

render json: {
  message: "Connexion réussie",
  utilisateur: utilisateur_json(utilisateur),
  organisation: organisation_json(utilisateur.organisation)
}, status: :ok
  end

  def me
    render json: {
      utilisateur: utilisateur_json(Current.utilisateur),
      organisation: organisation_json(Current.organisation),
      session: {
        id: Current.session.id,
        expire_at: Current.session.expire_at
      }
    }, status: :ok
  end

  def logout
    Current.session.update!(revoque_at: Time.current)

    cookies.delete(
      :access_token,
      httponly: true,
      secure: Rails.env.production?,
      same_site: :lax
    )

    render json: { message: "Déconnexion réussie" }, status: :ok
  end

  private

  def login_params
    params.permit(:email, :password)
  end

  def utilisateur_json(utilisateur)
    {
      id: utilisateur.id,
      email: utilisateur.email,
      nom: utilisateur.nom,
      prenom: utilisateur.prenom,
      role: utilisateur.role,
      actif: utilisateur.actif
    }
  end

  def organisation_json(organisation)
    {
      id: organisation.id,
      raison_sociale: organisation.raison_sociale,
      siret: organisation.siret,
      regime_tva: organisation.regime_tva
    }
  end
end