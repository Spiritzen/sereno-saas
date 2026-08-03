import type { EvenementDevis } from "../types/evenementDevis";
import { http } from "./http";
import { normalizeCollection } from "./normalize";

export async function listEvenementsDevis(
  devisId: string,
): Promise<EvenementDevis[]> {
  const response = await http.get<unknown>(`/devis/${devisId}/evenements`);

  return normalizeCollection<EvenementDevis>(response.data, "evenements_devis");
}
