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