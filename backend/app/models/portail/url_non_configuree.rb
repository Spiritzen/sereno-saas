# frozen_string_literal: true

module Portail
  # Levée par PortailFactureToken.frontend_base_url quand FRONTEND_URL est
  # absente ou invalide — en PRODUCTION uniquement pour l'absence (dev/test
  # ont un repli localhost), dans TOUS les environnements pour une valeur
  # syntaxiquement invalide (schéma/host manquant, http en prod). Échec
  # bruyant et actionnable, jamais un lien de portail silencieusement cassé.
  class UrlNonConfiguree < StandardError; end
end
