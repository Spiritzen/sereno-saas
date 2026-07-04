import type { Client, ClientInput } from "../types/client";
import { http } from "./http";
import { normalizeCollection, normalizeResource } from "./normalize";

export async function listClients(): Promise<Client[]> {
  const response = await http.get<unknown>("/clients");

  return normalizeCollection<Client>(response.data, "clients");
}

export async function getClient(id: string): Promise<Client> {
  const response = await http.get<unknown>(`/clients/${id}`);

  return normalizeResource<Client>(response.data, "client");
}

export async function createClient(input: ClientInput): Promise<Client> {
  const response = await http.post<unknown>("/clients", input);

  return normalizeResource<Client>(response.data, "client");
}

export async function updateClient(
  id: string,
  input: Partial<ClientInput>,
): Promise<Client> {
  const response = await http.patch<unknown>(`/clients/${id}`, input);

  return normalizeResource<Client>(response.data, "client");
}

export async function archiveClient(id: string): Promise<Client> {
  const response = await http.patch<unknown>(`/clients/${id}/archive`);

  return normalizeResource<Client>(response.data, "client");
}

export async function deleteClient(id: string): Promise<void> {
  await http.delete(`/clients/${id}`);
}
