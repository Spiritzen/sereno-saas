import type {
  LigneFacture,
  LigneFactureInput,
  LigneFactureUpdateInput,
} from "../types/ligneFacture";
import type { Facture } from "../types/facture";
import { http } from "./http";
import { normalizeCollection, normalizeResource } from "./normalize";

export async function listLignesFacture(
  factureId: string,
): Promise<LigneFacture[]> {
  const response = await http.get<unknown>(`/factures/${factureId}/lignes`);

  return normalizeCollection<LigneFacture>(response.data, "lignes_facture");
}

export async function createLigneFacture(
  factureId: string,
  input: LigneFactureInput,
): Promise<Facture> {
  const response = await http.post<unknown>(
    `/factures/${factureId}/lignes`,
    input,
  );

  return normalizeResource<Facture>(response.data, "facture");
}

export async function updateLigneFacture(
  id: string,
  input: LigneFactureUpdateInput,
): Promise<Facture> {
  const response = await http.patch<unknown>(`/lignes-facture/${id}`, input);

  return normalizeResource<Facture>(response.data, "facture");
}

export async function deleteLigneFacture(id: string): Promise<Facture> {
  const response = await http.delete<unknown>(`/lignes-facture/${id}`);

  return normalizeResource<Facture>(response.data, "facture");
}
