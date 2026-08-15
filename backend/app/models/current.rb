class Current < ActiveSupport::CurrentAttributes
  attribute :organisation
  attribute :utilisateur
  attribute :session

  # Espace client — Étape A (15/08/2026) — pile d'auth PARALLÈLE. JAMAIS posé
  # en même temps que :organisation/:utilisateur (deux pipelines distincts,
  # Api::V1::BaseController vs Destinataire::BaseController) : un destinataire
  # n'a jamais d'organisation, jamais.
  attribute :compte_destinataire
  attribute :destinataire_session
end
