import { useEffect, useMemo, useRef, useState, type ReactNode } from "react";
import * as destinataireApi from "../api/destinataireApi";
import { DESTINATAIRE_SESSION_MARKER_KEY } from "../api/destinataireHttp";
import type {
  CompteDestinataire,
  ConnexionInput,
  InscriptionInput,
} from "../types/destinataire";
import { DestinataireAuthContext, type DestinataireAuthContextValue } from "./DestinataireAuthContext";

function hasStoredSessionMarker() {
  return window.localStorage.getItem(DESTINATAIRE_SESSION_MARKER_KEY) === "true";
}

type DestinataireAuthProviderProps = {
  children: ReactNode;
};

// Espace client (C1) — JUMEAU de AuthProvider.tsx (même patron : marqueur
// localStorage DÉDIÉ, bootstrap via "qui suis-je" au montage SEULEMENT si le
// marqueur est présent), jamais une extension du contexte app (§1.1
// execution_espace_client_c1.txt). N'enveloppe QUE le sous-arbre de routes
// /espace-client (câblé dans App.tsx), jamais toute l'application.
export function DestinataireAuthProvider({ children }: DestinataireAuthProviderProps) {
  const [compte, setCompte] = useState<CompteDestinataire | null>(null);
  const [isLoading, setIsLoading] = useState(() => hasStoredSessionMarker());

  const hasBootstrapped = useRef(false);

  useEffect(() => {
    if (hasBootstrapped.current) {
      return;
    }

    hasBootstrapped.current = true;

    if (!hasStoredSessionMarker()) {
      return;
    }

    destinataireApi
      .moi()
      .then((payload) => {
        setCompte(payload);
      })
      .catch(() => {
        window.localStorage.removeItem(DESTINATAIRE_SESSION_MARKER_KEY);
        setCompte(null);
      })
      .finally(() => {
        setIsLoading(false);
      });
  }, []);

  async function handleLogin(input: ConnexionInput): Promise<void> {
    const payload = await destinataireApi.connexion(input);

    window.localStorage.setItem(DESTINATAIRE_SESSION_MARKER_KEY, "true");
    setCompte(payload);
  }

  async function handleActiverDepuisLien(input: InscriptionInput): Promise<void> {
    const payload = await destinataireApi.inscription(input);

    window.localStorage.setItem(DESTINATAIRE_SESSION_MARKER_KEY, "true");
    setCompte(payload);
  }

  async function handleLogout(): Promise<void> {
    await destinataireApi.deconnexion();

    window.localStorage.removeItem(DESTINATAIRE_SESSION_MARKER_KEY);
    setCompte(null);
  }

  const value = useMemo<DestinataireAuthContextValue>(
    () => ({
      compte,
      isAuthenticated: Boolean(compte),
      isLoading,
      login: handleLogin,
      activerDepuisLien: handleActiverDepuisLien,
      logout: handleLogout,
    }),
    [compte, isLoading],
  );

  return (
    <DestinataireAuthContext.Provider value={value}>{children}</DestinataireAuthContext.Provider>
  );
}
