import axios from "axios";
import type { PaSyncResult, TransmissionPa } from "../types/transmissionPa";
import { http } from "./http";
import { normalizeCollection, normalizeResource } from "./normalize";

// Miroir de transmissionPaApi.ts (facture), adapté aux routes avoir (V1.2c).
// Pas d'équivalent "relancer" côté avoir pour l'instant (non câblé côté
// backend, hors périmètre V1.2c) — volontairement absent ici.
export async function listTransmissionsPaAvoir(
  avoirId: string,
): Promise<TransmissionPa[]> {
  const response = await http.get<unknown>(`/avoirs/${avoirId}/transmissions`);

  return normalizeCollection<TransmissionPa>(response.data, "transmissions_pa");
}

export async function simulerTransmissionPaAvoir(
  avoirId: string,
): Promise<TransmissionPa> {
  const response = await http.post<unknown>(`/avoirs/${avoirId}/transmissions`);

  return normalizeResource<TransmissionPa>(response.data, "transmission");
}

export async function synchroniserTransmissionPaAvoir(
  avoirId: string,
): Promise<PaSyncResult> {
  const response = await http.post<PaSyncResult>(
    `/avoirs/${avoirId}/transmissions/synchroniser`,
  );

  return response.data;
}

// Même discipline que pour la facture : en cas d'échec technique (502), le
// backend renvoie quand même la TransmissionPa (statut "erreur").
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
