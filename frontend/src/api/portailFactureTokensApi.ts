import { http } from "./http";

// Endpoints OWNER (authentifiés, sous api/v1) — génère/révoque le lien de
// partage public d'une facture. Réponse à forme fixe {url}, pas une simple
// ressource — pas besoin de normalizeResource ici (même discipline que
// relancerFacture, cf. api/relancesApi.ts).
export async function genererLienPortail(factureId: string): Promise<string> {
  const response = await http.post<{ url: string }>(
    `/factures/${factureId}/lien_portail`,
  );

  return response.data.url;
}

export async function revoquerLienPortail(factureId: string): Promise<void> {
  await http.delete(`/factures/${factureId}/lien_portail`);
}
