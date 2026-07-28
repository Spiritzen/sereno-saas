import type { Avoir } from "../types/avoir";
import type { LigneAvoirInput, LigneAvoirUpdateInput } from "../types/ligneAvoir";
import { http } from "./http";
import { normalizeResource } from "./normalize";

// Miroir de lignesFactureApi.ts. Toutes les routes sont nichées sous
// /avoirs/:avoirId/lignes (pas de route à plat séparée, contrairement à
// lignes-facture : le frontend connaît toujours l'avoir courant). Chaque
// appel retourne l'AVOIR à jour (totaux recalculés côté backend), jamais
// juste la ligne — même discipline que pour la facture.
export async function createLigneAvoir(
  avoirId: string,
  input: LigneAvoirInput,
): Promise<Avoir> {
  const response = await http.post<unknown>(`/avoirs/${avoirId}/lignes`, {
    ligne_avoir: input,
  });

  return normalizeResource<Avoir>(response.data, "avoir");
}

export async function updateLigneAvoir(
  avoirId: string,
  ligneId: string,
  input: LigneAvoirUpdateInput,
): Promise<Avoir> {
  const response = await http.patch<unknown>(
    `/avoirs/${avoirId}/lignes/${ligneId}`,
    { ligne_avoir: input },
  );

  return normalizeResource<Avoir>(response.data, "avoir");
}

export async function deleteLigneAvoir(
  avoirId: string,
  ligneId: string,
): Promise<Avoir> {
  const response = await http.delete<unknown>(
    `/avoirs/${avoirId}/lignes/${ligneId}`,
  );

  return normalizeResource<Avoir>(response.data, "avoir");
}
