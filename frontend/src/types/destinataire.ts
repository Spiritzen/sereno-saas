// Espace client (C1) — types DISTINCTS de types/auth.ts (Utilisateur/Organisation) :
// un compte destinataire n'a ni rôle ni organisation.
export type CompteDestinataire = {
  email: string;
  fournisseurs_lies: number;
};

export type ConnexionInput = {
  email: string;
  mot_de_passe: string;
};

export type InscriptionInput = {
  token: string;
  email: string;
  mot_de_passe: string;
};
