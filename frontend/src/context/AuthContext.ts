import { createContext } from "react";
import type { LoginInput, Organisation, Utilisateur } from "../types/auth";

export type AuthContextValue = {
  utilisateur: Utilisateur | null;
  organisation: Organisation | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  login: (input: LoginInput) => Promise<void>;
  logout: () => Promise<void>;
};

export const AuthContext = createContext<AuthContextValue | null>(null);
