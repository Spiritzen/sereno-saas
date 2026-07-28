import type { Avoir, AvoirInput } from "../types/avoir";
import { http } from "./http";
import { normalizeCollection, normalizeResource } from "./normalize";

const API_BASE_URL =
  import.meta.env.VITE_API_BASE_URL ?? "http://localhost:3000/api/v1";

export async function listAvoirs(factureId?: string): Promise<Avoir[]> {
  const response = await http.get<unknown>("/avoirs", {
    params: factureId ? { facture_id: factureId } : undefined,
  });

  return normalizeCollection<Avoir>(response.data, "avoirs");
}

export async function getAvoir(id: string): Promise<Avoir> {
  const response = await http.get<unknown>(`/avoirs/${id}`);

  return normalizeResource<Avoir>(response.data, "avoir");
}

export async function createAvoir(input: AvoirInput): Promise<Avoir> {
  const response = await http.post<unknown>("/avoirs", { avoir: input });

  return normalizeResource<Avoir>(response.data, "avoir");
}

export async function emettreAvoir(id: string): Promise<Avoir> {
  const response = await http.post<unknown>(`/avoirs/${id}/emettre`);

  return normalizeResource<Avoir>(response.data, "avoir");
}

export function getAvoirPdfUrl(id: string) {
  return `${API_BASE_URL}/avoirs/${id}/pdf`;
}

export function getAvoirXmlUrl(id: string) {
  return `${API_BASE_URL}/avoirs/${id}/avoir_x_xml`;
}

// Garde-fou de montant CUMULÉ (V1.2d) : la somme des avoirs DÉJÀ ÉMIS sur
// une facture (jamais les brouillons, qui ne comptent pas encore). Le
// backend fait foi sur chaque total_ttc individuel (recalculé par
// lignes_avoir) ; cette fonction ne fait qu'additionner ce que le backend a
// déjà validé, elle n'invente aucun montant.
export function sommeAvoirsDejaEmis(
  avoirs: Avoir[],
  excludeAvoirId?: string,
): number {
  return avoirs
    .filter((avoir) => avoir.statut !== "brouillon" && avoir.id !== excludeAvoirId)
    .reduce((total, avoir) => total + Number(avoir.total_ttc ?? 0), 0);
}
