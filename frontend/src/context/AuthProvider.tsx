import { useCallback, useEffect, useMemo, useRef, useState, type ReactNode } from "react";
import * as authApi from "../api/authApi";
import type { LoginInput, Organisation, Utilisateur } from "../types/auth";
import { AuthContext, type AuthContextValue } from "./AuthContext";

const SESSION_MARKER_KEY = "sereno.session.active";

function hasStoredSessionMarker() {
  return window.localStorage.getItem(SESSION_MARKER_KEY) === "true";
}

type AuthProviderProps = {
  children: ReactNode;
};

export function AuthProvider({ children }: AuthProviderProps) {
  const [utilisateur, setUtilisateur] = useState<Utilisateur | null>(null);
  const [organisation, setOrganisation] = useState<Organisation | null>(null);
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

    authApi
      .me()
      .then((payload) => {
        setUtilisateur(payload.utilisateur);
        setOrganisation(payload.organisation);
      })
      .catch(() => {
        window.localStorage.removeItem(SESSION_MARKER_KEY);
        setUtilisateur(null);
        setOrganisation(null);
      })
      .finally(() => {
        setIsLoading(false);
      });
  }, []);

  // R3 (§9) — primitive d'hydratation UNIQUE : pose le marqueur local, PUIS
  // appelle me() pour hydrater Utilisateur + Organisation depuis les cookies
  // HttpOnly déjà posés par le backend (login OU inscription). Si me()
  // échoue (cookies absents/invalides — cas attendu de
  // session_active:false), nettoie le marqueur et rétablit un état anonyme
  // honnête plutôt que de laisser croire à une authentification. Ne lève
  // jamais : retourne un booléen, l'appelant décide de la suite.
  const completeAuthentication = useCallback(async (): Promise<boolean> => {
    window.localStorage.setItem(SESSION_MARKER_KEY, "true");

    try {
      const payload = await authApi.me();

      setUtilisateur(payload.utilisateur);
      setOrganisation(payload.organisation);

      return true;
    } catch {
      window.localStorage.removeItem(SESSION_MARKER_KEY);
      setUtilisateur(null);
      setOrganisation(null);

      return false;
    }
  }, []);

  const handleLogin = useCallback(
    async (input: LoginInput): Promise<void> => {
      await authApi.login(input);

      // Converge vers la MÊME primitive que l'inscription (§9) — jamais deux
      // logiques d'hydratation divergentes. Un login qui vient de réussir mais
      // dont l'hydratation échoue est un état inattendu (pas le cas
      // session_active:false, documenté et honnête, propre à l'inscription) :
      // signalé par une erreur explicite plutôt que silencieusement ignoré.
      const hydrated = await completeAuthentication();

      if (!hydrated) {
        throw new Error("Connexion réussie mais session introuvable. Réessayez.");
      }
    },
    [completeAuthentication],
  );

  const handleLogout = useCallback(async (): Promise<void> => {
    await authApi.logout();

    window.localStorage.removeItem(SESSION_MARKER_KEY);

    setUtilisateur(null);
    setOrganisation(null);
  }, []);

  const value = useMemo<AuthContextValue>(
    () => ({
      utilisateur,
      organisation,
      isAuthenticated: Boolean(utilisateur),
      isLoading,
      login: handleLogin,
      logout: handleLogout,
      completeAuthentication,
    }),
    [utilisateur, organisation, isLoading, handleLogin, handleLogout, completeAuthentication],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}