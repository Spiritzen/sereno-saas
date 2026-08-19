import axios, { type AxiosError } from "axios";

// Espace client (C1) — client HTTP DÉDIÉ, jamais une réutilisation de `http`
// (api/http.ts, réservé aux utilisateurs de l'app) : base URL, cookies et
// gestion du 401 totalement SÉPARÉS (§1.1 execution_espace_client_c1.txt).
// Monté sur /destinataire (hors /api/v1), comme le backend le déclare
// (config/routes.rb, namespace :destinataire).
// Exportée (C2) pour construire l'URL brute du PDF (window.open, cookies
// envoyés par la navigation — même patron que getFacturePortailPdfUrl /
// getFecExportUrl), sans dupliquer la logique de résolution d'URL.
export const DESTINATAIRE_BASE_URL =
  import.meta.env.VITE_DESTINATAIRE_BASE_URL ?? "http://localhost:3000/destinataire";

// Clé de stockage DÉDIÉE (§1.2) — jamais "sereno.session.active" (celle de
// l'app, cf. AuthProvider.tsx). Exportée pour que DestinataireAuthProvider
// et cet intercepteur restent la SEULE source de vérité de ce nom.
export const DESTINATAIRE_SESSION_MARKER_KEY = "sereno.destinataire.session.active";

// fix_espace_client_auth_deconnexion — événement DOM dédié, dispatché sur un
// 401 destinataire. Ce fichier n'a AUCUNE dépendance React (axios pur) : il
// ne peut pas appeler setCompte(null) lui-même. DestinataireAuthProvider
// s'abonne à cet événement pour invalider son état EN MÉMOIRE au moment où
// le 401 survient, plutôt que de compter sur un futur remontage (qui
// n'arrive jamais dans une SPA sans rechargement complet) — cause racine du
// bandeau "Authentification requise" affiché en plein milieu de l'écran.
export const DESTINATAIRE_SESSION_EXPIREE_EVENT = "destinataire:session-expiree";

// Helper partagé (page liste + page détail) pour ne JAMAIS afficher le 401
// brut du backend comme une erreur de contenu de page : un 401 destinataire
// est toujours un problème de SESSION, jamais un problème de DONNÉES — la
// redirection vers la connexion (via le contexte + ProtectedDestinataireRoute)
// s'en charge.
export function estErreurNonAuthentifie(error: unknown): boolean {
  return (
    typeof error === "object" &&
    error !== null &&
    "response" in error &&
    (error as { response?: { status?: number } }).response?.status === 401
  );
}

export const destinataireHttp = axios.create({
  baseURL: DESTINATAIRE_BASE_URL,
  withCredentials: true,
  headers: {
    "Content-Type": "application/json",
  },
});

// ⚠️ Pas d'endpoint de refresh côté destinataire aujourd'hui (reco du
// 16/08/2026 — access token 30 min, aucune route de renouvellement livrée
// aux étapes A/B). Contrairement à http.ts, cet intercepteur NE RETENTE
// JAMAIS la requête : sur un 401, il efface le marqueur de session ET
// dispatche DESTINATAIRE_SESSION_EXPIREE_EVENT pour que le contexte React
// invalide `compte` IMMÉDIATEMENT (fix_espace_client_auth_deconnexion —
// avant ce correctif, seul le localStorage était nettoyé : le contexte
// restait authentifié en mémoire jusqu'au prochain rechargement complet,
// ce qui laissait le garde ProtectedDestinataireRoute laisser passer
// l'écran malgré une session backend déjà morte).
destinataireHttp.interceptors.response.use(
  (response) => response,
  (error: AxiosError) => {
    if (error.response?.status === 401) {
      window.localStorage.removeItem(DESTINATAIRE_SESSION_MARKER_KEY);
      window.dispatchEvent(new Event(DESTINATAIRE_SESSION_EXPIREE_EVENT));
    }

    return Promise.reject(error);
  },
);
