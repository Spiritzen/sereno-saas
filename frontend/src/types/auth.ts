export type Utilisateur = {
  id: string;
  email: string;
  nom: string;
  prenom: string;
  role: "super_admin" | "owner" | "comptable" | "membre";
  actif: boolean;
};

export type Organisation = {
  id: string;
  raison_sociale: string;
  siret: string;
  regime_tva: string;
};

export type AuthPayload = {
  utilisateur: Utilisateur;
  organisation: Organisation;
};

export type LoginInput = {
  email: string;
  password: string;
};

// R3 (prompt_claude_code_inscription_owner_frontend_r3.txt §4) — valeurs
// EXACTES autorisées par le backend (Organisation#regime_tva, cf.
// backend/app/models/organisation.rb) : jamais inventées, jamais une 4e
// valeur ajoutée côté frontend sans le backend.
export type RegimeTva = "franchise" | "reel_simplifie" | "reel_normal";

export type InscriptionUtilisateurInput = {
  prenom: string;
  nom: string;
  email: string;
  mot_de_passe: string;
  confirmation_mot_de_passe: string;
};

export type InscriptionOrganisationInput = {
  raison_sociale: string;
  siret: string;
  regime_tva: RegimeTva;
  adresse_ligne1: string;
  code_postal: string;
  ville: string;
  pays: string;
  email: string;
};

// Forme EXACTE du payload attendu par POST /api/v1/inscription (backend
// R2/R2.1, confirmé en lisant Api::V1::InscriptionsController) : imbriqué
// sous une clé `inscription`, jamais de role/organisation_id/id/actif — ces
// clés n'existent simplement pas dans ce type.
export type InscriptionInput = {
  utilisateur: InscriptionUtilisateurInput;
  organisation: InscriptionOrganisationInput;
};

// Forme EXACTE de la réponse 201 (confirmée en lisant
// Api::V1::InscriptionsController#create) : mêmes types Utilisateur/
// Organisation que le login, plus `session_active` (R2.1 §5).
export type InscriptionResponse = {
  message: string;
  utilisateur: Utilisateur;
  organisation: Organisation;
  session_active: boolean;
};