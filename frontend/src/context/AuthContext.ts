import { createContext } from "react";
import type { LoginInput, Organisation, Utilisateur } from "../types/auth";

export type AuthContextValue = {
  utilisateur: Utilisateur | null;
  organisation: Organisation | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  login: (input: LoginInput) => Promise<void>;
  logout: () => Promise<void>;
  // R3 (prompt_claude_code_inscription_owner_frontend_r3.txt §9) — primitive
  // d'hydratation UNIQUE (marqueur local + appel me() sur les cookies
  // HttpOnly déjà posés par le backend). `login()` ci-dessus ET l'inscription
  // (InscriptionPage, après un 201 session_active:true) convergent tous les
  // deux vers CETTE méthode plutôt que de dupliquer la logique. Retourne
  // `true` si l'hydratation a réussi, `false` si elle a échoué (marqueur
  // nettoyé, état réinitialisé) — jamais un throw, pour que l'appelant décide
  // honnêtement de la suite (proposer la connexion) sans état incohérent.
  completeAuthentication: () => Promise<boolean>;
};

export const AuthContext = createContext<AuthContextValue | null>(null);
