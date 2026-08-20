# frozen_string_literal: true

# Rate limiting ciblé de DEUX surfaces publiques (aucune auth JWT) :
#   1) webhook PA entrant (POST /webhooks/pa) — R6.
#   2) portail public de factures (GET /portail/factures/:token[/pdf|/avoirs])
#      — dette n°33.
# Chaque throttle ne matche QUE sa propre surface : le bloc discriminateur
# retourne nil (donc aucun throttle appliqué, cf.
# Rack::Attack::Throttle#matched_by?) pour toute autre route, y compris
# l'API authentifiée (déjà protégée par JWT). Jamais de throttle générique
# sur req.ip seul qui toucherait tout le trafic.
#
# LE THROTTLE PAR ORGANISATION (webhook) NE VIT PAS ICI. L'identifiant de
# rattachement (identifiant_pa) n'existe QUE dans le corps JSON de la
# requête — ni URL, ni header (cf. Webhooks::PaController). Le lire ici, au
# niveau middleware, AVANT que le contrôleur n'ait lu request.raw_post pour
# la vérification de signature, risquerait de consommer/altérer ce corps
# dont la signature a besoin OCTET POUR OCTET (B3.3 : "le raw body est
# sacré"). Le principe posé pour R6 est explicite : la signature prime sur
# la granularité du throttle. Le throttle organisation est donc appliqué
# APRÈS résolution, dans Webhooks::PaController#organisation_throttlee?, via
# le MÊME cache Rack::Attack (Rack::Attack.cache.count, même store, même
# sémantique de fenêtre) — chaque couche vérifie ce qu'elle peut voir à son
# niveau. Le portail public n'a pas cet équivalent : le token n'est JAMAIS
# décodé/résolu ici (aucun accès base depuis le middleware) — seule l'IP
# protège cette surface, à dessein plus simple que le webhook.
#
# Store : Rails.cache (Solid Cache en production, memory_store en dev/test —
# cf. config/environments/*.rb). Jamais Redis : rien de nouveau à opérer.
Rack::Attack.cache.store = Rails.cache

Rack::Attack.throttle("webhooks/pa/ip", limit: 60, period: 60) do |req|
  req.ip if req.post? && req.path == "/webhooks/pa"
end

# Dette n°33 — portail public de factures. Un SEUL throttle pour les 3
# variantes (show/pdf/avoirs) : le compteur est partagé (même clé
# "portail/factures/ip" pour req.ip, cf. sémantique Rack::Attack), donc un
# appelant ne peut pas contourner le seuil en alternant les 3 routes.
# Chemin filtré par un motif PRÉCIS — couvre aussi les tokens invalides
# (aucune contrainte de format hexadécimal ici : un attaquant qui bombarde
# avec des tokens au hasard doit être throttlé comme un appelant légitime).
# Jamais le token lui-même comme discriminateur (cf. commentaire ci-dessus) :
# seule l'IP.
Rack::Attack.throttle("portail/factures/ip", limit: 60, period: 60) do |req|
  req.ip if req.get? && req.path.match?(%r{\A/portail/factures/[^/]+(?:/(?:pdf|avoirs))?\z})
end

# Réponse 429 sobre : aucun détail sur le seuil exact ni sur l'état interne
# ne doit être exposé à un appelant hostile — juste de quoi permettre à un
# appelant légitime de savoir qu'il peut réessayer plus tard. Partagée par
# les DEUX throttles ci-dessus, jamais dupliquée.
Rack::Attack.throttled_responder = lambda do |req|
  match_data = req.env["rack.attack.match_data"]
  headers = { "content-type" => "application/json" }

  if match_data
    retry_after = match_data[:period] - (match_data[:epoch_time] % match_data[:period])
    headers["retry-after"] = retry_after.to_s
  end

  [ 429, headers, [ { error: "rate_limited" }.to_json ] ]
end
