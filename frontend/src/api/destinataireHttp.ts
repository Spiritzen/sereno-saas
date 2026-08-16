import axios, { type AxiosError } from "axios";

// Espace client (C1) — client HTTP DÉDIÉ, jamais une réutilisation de `http`
// (api/http.ts, réservé aux utilisateurs de l'app) : base URL, cookies et
// gestion du 401 totalement SÉPARÉS (§1.1 execution_espace_client_c1.txt).
// Monté sur /destinataire (hors /api/v1), comme le backend le déclare
// (config/routes.rb, namespace :destinataire).
const DESTINATAIRE_BASE_URL =
  import.meta.env.VITE_DESTINATAIRE_BASE_URL ?? "http://localhost:3000/destinataire";

// Clé de stockage DÉDIÉE (§1.2) — jamais "sereno.session.active" (celle de
// l'app, cf. AuthProvider.tsx). Exportée pour que DestinataireAuthProvider
// et cet intercepteur restent la SEULE source de vérité de ce nom.
export const DESTINATAIRE_SESSION_MARKER_KEY = "sereno.destinataire.session.active";

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
// JAMAIS la requête : sur un 401, il efface seulement le marqueur de
// session, pour que le prochain rendu de ProtectedDestinataireRoute
// redirige proprement vers la connexion plutôt que de rester bloqué sur un
// état "connecté" obsolète. Limite assumée pour C1, cf. rapport.
destinataireHttp.interceptors.response.use(
  (response) => response,
  (error: AxiosError) => {
    if (error.response?.status === 401) {
      window.localStorage.removeItem(DESTINATAIRE_SESSION_MARKER_KEY);
    }

    return Promise.reject(error);
  },
);
