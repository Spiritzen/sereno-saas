import { createContext } from "react";
import type {
  CompteDestinataire,
  ConnexionInput,
  InscriptionInput,
} from "../types/destinataire";

export type DestinataireAuthContextValue = {
  compte: CompteDestinataire | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  login: (input: ConnexionInput) => Promise<void>;
  activerDepuisLien: (input: InscriptionInput) => Promise<void>;
  logout: () => Promise<void>;
};

export const DestinataireAuthContext = createContext<DestinataireAuthContextValue | null>(null);
