import { useEffect, useMemo, useRef, useState, type ReactNode } from "react";
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

  async function handleLogin(input: LoginInput): Promise<void> {
    const payload = await authApi.login(input);

    window.localStorage.setItem(SESSION_MARKER_KEY, "true");

    setUtilisateur(payload.utilisateur);
    setOrganisation(payload.organisation);
  }

  async function handleLogout(): Promise<void> {
    await authApi.logout();

    window.localStorage.removeItem(SESSION_MARKER_KEY);

    setUtilisateur(null);
    setOrganisation(null);
  }

  const value = useMemo<AuthContextValue>(
    () => ({
      utilisateur,
      organisation,
      isAuthenticated: Boolean(utilisateur),
      isLoading,
      login: handleLogin,
      logout: handleLogout,
    }),
    [utilisateur, organisation, isLoading],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}