import type {
  Facture,
  FactureInput,
  FactureUpdateInput,
} from "../types/facture";
import type { ConformiteResult } from "../types/conformite";
import { http } from "./http";
import { normalizeCollection, normalizeResource } from "./normalize";

export async function listFactures(): Promise<Facture[]> {
  const response = await http.get<unknown>("/factures");

  return normalizeCollection<Facture>(response.data, "factures");
}

export async function getFacture(id: string): Promise<Facture> {
  const response = await http.get<unknown>(`/factures/${id}`);

  return normalizeResource<Facture>(response.data, "facture");
}

export async function createFacture(input: FactureInput): Promise<Facture> {
  const response = await http.post<unknown>("/factures", input);

  return normalizeResource<Facture>(response.data, "facture");
}

export async function updateFacture(
  id: string,
  input: FactureUpdateInput,
): Promise<Facture> {
  const response = await http.patch<unknown>(`/factures/${id}`, input);

  return normalizeResource<Facture>(response.data, "facture");
}

export async function deleteFacture(id: string): Promise<void> {
  await http.delete(`/factures/${id}`);
}

export async function emettreFacture(id: string): Promise<Facture> {
  const response = await http.post<unknown>(`/factures/${id}/emettre`);

  return normalizeResource<Facture>(response.data, "facture");
}

export async function getConformiteFacture(
  id: string,
): Promise<ConformiteResult> {
  const response = await http.get<unknown>(`/factures/${id}/conformite`);

  return normalizeResource<ConformiteResult>(response.data, "conformite");
}
