import type {
  CompteDestinataire,
  ConnexionInput,
  InscriptionInput,
} from "../types/destinataire";
import { destinataireHttp } from "./destinataireHttp";

// Réponse à forme fixe {email, fournisseurs_lies} sur les 3 endpoints —
// même discipline que relancerFacture (relancesApi.ts) : pas besoin de
// normalizeResource ici.
export async function connexion(input: ConnexionInput): Promise<CompteDestinataire> {
  const response = await destinataireHttp.post<CompteDestinataire>("/connexion", input);

  return response.data;
}

export async function inscription(input: InscriptionInput): Promise<CompteDestinataire> {
  const response = await destinataireHttp.post<CompteDestinataire>("/inscription", input);

  return response.data;
}

export async function moi(): Promise<CompteDestinataire> {
  const response = await destinataireHttp.get<CompteDestinataire>("/moi");

  return response.data;
}

export async function deconnexion(): Promise<void> {
  await destinataireHttp.delete("/connexion");
}
