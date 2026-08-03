import type { Devis, DevisInput, DevisUpdateInput } from "../types/devis";
import type { Facture } from "../types/facture";
import { http } from "./http";
import { normalizeCollection, normalizeResource } from "./normalize";

export async function listDevis(params?: {
  statut?: string;
  client_id?: string;
}): Promise<Devis[]> {
  const response = await http.get<unknown>("/devis", { params });

  return normalizeCollection<Devis>(response.data, "devis");
}

export async function getDevis(id: string): Promise<Devis> {
  const response = await http.get<unknown>(`/devis/${id}`);

  return normalizeResource<Devis>(response.data, "devis");
}

export async function createDevis(input: DevisInput): Promise<Devis> {
  const response = await http.post<unknown>("/devis", { devis: input });

  return normalizeResource<Devis>(response.data, "devis");
}

export async function updateDevis(
  id: string,
  input: DevisUpdateInput,
): Promise<Devis> {
  const response = await http.patch<unknown>(`/devis/${id}`, { devis: input });

  return normalizeResource<Devis>(response.data, "devis");
}

export async function deleteDevis(id: string): Promise<void> {
  await http.delete(`/devis/${id}`);
}

export async function envoyerDevis(id: string): Promise<Devis> {
  const response = await http.post<unknown>(`/devis/${id}/envoyer`);

  return normalizeResource<Devis>(response.data, "devis");
}

export async function accepterDevis(id: string): Promise<Devis> {
  const response = await http.post<unknown>(`/devis/${id}/accepter`);

  return normalizeResource<Devis>(response.data, "devis");
}

export async function refuserDevis(id: string): Promise<Devis> {
  const response = await http.post<unknown>(`/devis/${id}/refuser`);

  return normalizeResource<Devis>(response.data, "devis");
}

// Convertit un devis ACCEPTÉ en facture définitive (DevisConversionService,
// backend) : renvoie la FACTURE créée (FactureBlueprint), pas le devis — le
// frontend navigue directement dessus après succès.
export async function convertirDevis(id: string): Promise<Facture> {
  const response = await http.post<unknown>(`/devis/${id}/convertir`);

  return normalizeResource<Facture>(response.data, "facture");
}
