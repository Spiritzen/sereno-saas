import type { RelanceResult } from "../types/relance";
import { http } from "./http";

// Calqué sur synchroniserTransmissionPa (transmissionPaApi) : réponse à
// forme fixe {relance, facture}, pas une simple ressource — pas besoin de
// normalizeResource ici.
export async function relancerFacture(factureId: string): Promise<RelanceResult> {
  const response = await http.post<RelanceResult>(`/factures/${factureId}/relances`);

  return response.data;
}
