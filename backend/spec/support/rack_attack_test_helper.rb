# frozen_string_literal: true

# R6 — Rack::Attack partage un cache (Rails.cache) qui vit HORS de la
# transaction DB de chaque exemple (config.use_transactional_fixtures ne le
# concerne pas) : sans reset, les compteurs de requêtes s'accumuleraient
# d'un exemple à l'autre et rendraient le seuil de throttle imprévisible.
# Reset avant CHAQUE exemple, pas seulement ceux qui testent le rate
# limiting, pour que tout le reste de la suite (T-RAW-BODY, T-SIGNATURE-OK,
# T-CROSS-TENANT...) parte toujours d'un compteur à zéro.
RSpec.configure do |config|
  config.before do
    Rack::Attack.cache.store.clear
  end
end
