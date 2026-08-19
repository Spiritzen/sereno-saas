import { useEffect, useMemo, useRef, useState, type ReactNode } from "react";
import * as destinataireApi from "../api/destinataireApi";
import {
  DESTINATAIRE_SESSION_EXPIREE_EVENT,
  DESTINATAIRE_SESSION_MARKER_KEY,
} from "../api/destinataireHttp";
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

  // fix_espace_client_auth_deconnexion — invalide `compte` DÈS qu'un 401
  // destinataire survient n'importe où dans l'app (pas seulement au
  // bootstrap ci-dessus), sans attendre un rechargement complet. Sans ça,
  // ProtectedDestinataireRoute continuait de lire un `compte` obsolète
  // (toujours vérité) après l'expiration réelle de la session côté backend,
  // laissant l'écran protégé s'afficher avec l'erreur du backend au milieu
  // au lieu de rediriger vers la connexion.
  useEffect(() => {
    function handleSessionExpiree() {
      setCompte(null);
    }

    window.addEventListener(DESTINATAIRE_SESSION_EXPIREE_EVENT, handleSessionExpiree);

    return () => {
      window.removeEventListener(DESTINATAIRE_SESSION_EXPIREE_EVENT, handleSessionExpiree);
    };
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

  // fix_espace_client_auth_deconnexion — nettoyage LOCAL (marqueur + compte)
  // désormais INCONDITIONNEL : avant ce correctif, si l'appel backend
  // échouait (ex. session déjà morte côté serveur → 401 sur le DELETE
  // lui-même), l'exception interrompait la fonction AVANT le nettoyage —
  // `compte` restait vérité, donc EspaceClientConnexionPage
  // (`if (isAuthenticated) return <Navigate to="/espace-client" />`)
  // renvoyait aussitôt l'utilisateur vers l'écran protégé : "Se déconnecter"
  // ne permettait plus de revenir se reconnecter. L'échec backend est avalé
  // volontairement (catch vide) : une déconnexion est avant tout un geste
  // LOCAL, elle ne doit jamais rester bloquée par un backend injoignable ou
  // une session déjà expirée côté serveur.
  async function handleLogout(): Promise<void> {
    try {
      await destinataireApi.deconnexion();
    } catch {
      // Session déjà invalide côté backend (ou réseau indisponible) : sans
      // objet, le nettoyage local ci-dessous a lieu de toute façon.
    } finally {
      window.localStorage.removeItem(DESTINATAIRE_SESSION_MARKER_KEY);
      setCompte(null);
    }
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
