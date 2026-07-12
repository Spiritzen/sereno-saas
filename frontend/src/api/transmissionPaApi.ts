import axios from "axios";
import type { TransmissionPa } from "../types/transmissionPa";
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
