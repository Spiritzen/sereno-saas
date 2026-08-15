import axios from "axios";
import type { PortailAvoir, PortailFacture } from "../types/portail";
import { normalizeCollection, normalizeResource } from "./normalize";

// Portail destinataire (MVP) — client HTTP DÉLIBÉRÉMENT séparé de `http`
// (api/http.ts) : aucun cookie de session (withCredentials: false, valeur
// par défaut d'axios), aucun intercepteur de refresh JWT — cette page n'a
// et n'aura jamais de session, seul le token dans l'URL fait foi. Ne
// JAMAIS réutiliser `http` ici, même si ça semblait plus simple : ce
// serait envoyer inutilement des cookies d'un éventuel visiteur déjà
// connecté par ailleurs vers un endpoint public qui n'en a aucun usage.
const PORTAIL_BASE_URL =
  import.meta.env.VITE_PORTAIL_BASE_URL ?? "http://localhost:3000/portail";

const portailHttp = axios.create({
  baseURL: PORTAIL_BASE_URL,
  headers: {
    "Content-Type": "application/json",
  },
});

export async function getFacturePortail(token: string): Promise<PortailFacture> {
  const response = await portailHttp.get<unknown>(`/factures/${token}`);

  return normalizeResource<PortailFacture>(response.data, "facture");
}

export async function listAvoirsPortail(token: string): Promise<PortailAvoir[]> {
  const response = await portailHttp.get<unknown>(`/factures/${token}/avoirs`);

  return normalizeCollection<PortailAvoir>(response.data, "avoirs");
}

export function getFacturePortailPdfUrl(token: string) {
  return `${PORTAIL_BASE_URL}/factures/${token}/pdf`;
}
