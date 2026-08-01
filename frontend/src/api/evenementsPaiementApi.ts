import type { EvenementPaiement } from "../types/evenementPaiement";
import { http } from "./http";
import { normalizeCollection } from "./normalize";

export async function listEvenementsPaiement(
  factureId: string,
  paiementId: string,
): Promise<EvenementPaiement[]> {
  const response = await http.get<unknown>(
    `/factures/${factureId}/paiements/${paiementId}/evenements`,
  );

  return normalizeCollection<EvenementPaiement>(response.data, "evenements_paiement");
}
