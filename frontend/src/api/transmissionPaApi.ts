import axios from "axios";
import type { PaSyncResult, TransmissionPa } from "../types/transmissionPa";
import { http } from "./http";
import { normalizeCollection, normalizeResource } from "./normalize";

export async function listTransmissionsPa(
  factureId: string,
): Promise<TransmissionPa[]> {
  const response = await http.get<unknown>(
    `/factures/${factureId}/transmissions`,
  );

  return normalizeCollection<TransmissionPa>(response.data, "transmissions_pa");
}

export async function simulerTransmissionPa(
  factureId: string,
): Promise<TransmissionPa> {
  const response = await http.post<unknown>(
    `/factures/${factureId}/transmissions`,
  );

  return normalizeResource<TransmissionPa>(response.data, "transmission");
}

export async function synchroniserTransmissionPa(
  factureId: string,
): Promise<PaSyncResult> {
  const response = await http.post<PaSyncResult>(
    `/factures/${factureId}/transmissions/synchroniser`,
  );

  return response.data;
}

export async function relancerTransmissionPa(
  factureId: string,
): Promise<TransmissionPa> {
  const response = await http.post<unknown>(
    `/factures/${factureId}/transmissions/relancer`,
  );

  return normalizeResource<TransmissionPa>(response.data, "transmission");
}

export async function getRequiresReviewCount(): Promise<number> {
  const response = await http.get<{ requires_review_count: number }>(
    "/transmissions_pa/review_count",
  );

  return response.data.requires_review_count;
}

// En cas d'échec technique (502), le backend renvoie quand même la
// TransmissionPa (statut "erreur") dans le corps de l'erreur : ça permet à
// l'UI d'afficher l'échec sans re-fetch, sans jamais bloquer l'utilisateur.
export function getTransmissionFromError(
  error: unknown,
): TransmissionPa | null {
  if (!axios.isAxiosError(error)) {
    return null;
  }

  const data = error.response?.data as
    | { transmission?: TransmissionPa }
    | undefined;

  return data?.transmission ?? null;
}
