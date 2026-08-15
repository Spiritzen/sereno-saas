# frozen_string_literal: true

# Export FEC (MVP, 15/08/2026) — tenant-scopé (Current.organisation), lecture
# seule. Deux actions : #fec_apercu (JSON léger, étiquette + nom de fichier —
# pour l'afficher AVANT le téléchargement, cf. §5) et #fec (le fichier lui-même,
# en pièce jointe). Toute la logique vit dans FecExportService — ce
# contrôleur ne fait qu'appeler, valider les dates, jamais réimplémenter.
class Api::V1::ExportsController < Api::V1::BaseController
  def fec_apercu
    authorize :fec_export, :creer?, policy_class: FecExportPolicy

    debut, fin = plage_dates
    return render_dates_invalides if debut.blank?

    service = FecExportService.new(organisation: Current.organisation, debut: debut, fin: fin)

    render json: { etiquette: service.etiquette, nom_fichier: service.nom_fichier }, status: :ok
  end

  def fec
    authorize :fec_export, :creer?, policy_class: FecExportPolicy

    debut, fin = plage_dates
    return render_dates_invalides if debut.blank?

    resultat = FecExportService.new(organisation: Current.organisation, debut: debut, fin: fin).call

    # En-tête dédié (§6) — valeur PERCENT-ENCODÉE (Rack::Utils.escape) : un
    # en-tête HTTP n'est pas garanti sûr pour de l'UTF-8 accentué brut (—, é,
    # à...). Le frontend affiche déjà l'étiquette via #fec_apercu AVANT ce
    # téléchargement ; cet en-tête reste un filet pour un appel direct à
    # l'API (curl, etc.), pas le chemin principal.
    response.set_header("X-Fec-Etiquette", Rack::Utils.escape(resultat.etiquette))

    send_data resultat.contenu,
              type: "text/plain; charset=utf-8",
              disposition: "attachment",
              filename: resultat.nom_fichier
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def plage_dates
    debut = parser_date(params[:debut])
    fin = parser_date(params[:fin])

    return [ nil, nil ] if debut.blank? || fin.blank? || debut > fin

    [ debut, fin ]
  end

  def parser_date(valeur)
    Date.iso8601(valeur.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def render_dates_invalides
    render json: {
      error: "Plage de dates invalide",
      details: [ "debut et fin sont requis, au format AAAA-MM-JJ, avec debut <= fin" ]
    }, status: :unprocessable_entity
  end
end
