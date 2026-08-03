import type { Devis } from "../types/devis";
import type {
  LigneDevisInput,
  LigneDevisUpdateInput,
} from "../types/ligneDevis";
import { http } from "./http";
import { normalizeResource } from "./normalize";

// Miroir de lignesAvoirApi.ts. Toutes les routes sont nichées sous
// /devis/:devisId/lignes (pas de route à plat séparée). Chaque appel
// retourne le DEVIS à jour (totaux recalculés côté backend via
// FactureTotalsService), jamais juste la ligne.
export async function createLigneDevis(
  devisId: string,
  input: LigneDevisInput,
): Promise<Devis> {
  const response = await http.post<unknown>(`/devis/${devisId}/lignes`, {
    ligne_devis: input,
  });

  return normalizeResource<Devis>(response.data, "devis");
}

export async function updateLigneDevis(
  devisId: string,
  ligneId: string,
  input: LigneDevisUpdateInput,
): Promise<Devis> {
  const response = await http.patch<unknown>(
    `/devis/${devisId}/lignes/${ligneId}`,
    { ligne_devis: input },
  );

  return normalizeResource<Devis>(response.data, "devis");
}

export async function deleteLigneDevis(
  devisId: string,
  ligneId: string,
): Promise<Devis> {
  const response = await http.delete<unknown>(
    `/devis/${devisId}/lignes/${ligneId}`,
  );

  return normalizeResource<Devis>(response.data, "devis");
}
