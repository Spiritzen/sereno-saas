import type { EvenementFacture } from "../types/evenementFacture";
import { http } from "./http";
import { normalizeCollection } from "./normalize";

export async function listEvenementsFacture(
  factureId: string,
): Promise<EvenementFacture[]> {
  const response = await http.get<unknown>(`/factures/${factureId}/evenements`);

  return normalizeCollection<EvenementFacture>(response.data, "evenements_facture");
}
