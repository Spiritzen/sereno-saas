import type { EvenementAvoir } from "../types/evenementAvoir";
import { http } from "./http";
import { normalizeCollection } from "./normalize";

export async function listEvenementsAvoir(
  avoirId: string,
): Promise<EvenementAvoir[]> {
  const response = await http.get<unknown>(`/avoirs/${avoirId}/evenements`);

  return normalizeCollection<EvenementAvoir>(response.data, "evenements_avoir");
}
