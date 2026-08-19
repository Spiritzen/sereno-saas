import type {
  CompteDestinataire,
  ConnexionInput,
  InscriptionInput,
} from "../types/destinataire";
import type {
  EspaceClientFactureDetail,
  EspaceClientFacturesReponse,
  EspaceClientFournisseurEntree,
  ListerFacturesParams,
} from "../types/espaceClient";
import { DESTINATAIRE_BASE_URL, destinataireHttp } from "./destinataireHttp";

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

// C2 — recherche/filtre/tri passent par les PARAMÈTRES de l'API (§1.3
// execution_espace_client_c2.txt) : jamais un re-filtrage local d'un gros
// jeu chargé une fois. Réponse enveloppée {groupes, pagination} depuis
// execution_espace_client_sidebar_pagination_badge.txt §3 (pagination RÉELLE
// à 10/page, jamais un chargement complet en mémoire).
export async function listerFactures(
  params: ListerFacturesParams = {},
): Promise<EspaceClientFacturesReponse> {
  const response = await destinataireHttp.get<EspaceClientFacturesReponse>("/factures", {
    params,
  });

  return response.data;
}

export async function getFacture(id: string): Promise<EspaceClientFactureDetail> {
  const response = await destinataireHttp.get<EspaceClientFactureDetail>(`/factures/${id}`);

  return response.data;
}

// Même patron que getFacturePortailPdfUrl (portailApi.ts) / getFecExportUrl
// (exportsApi.ts) : une URL brute ouverte via window.open — les cookies
// d'auth destinataire (HttpOnly) partent avec la navigation.
export function getFacturePdfUrl(id: string): string {
  return `${DESTINATAIRE_BASE_URL}/factures/${id}/pdf`;
}

// §2 — sidebar "Mes fournisseurs" : vue agrégée dédiée, volontairement NON
// paginée côté backend (cardinalité faible, cf. Destinataire::FournisseursController).
export async function listerFournisseurs(): Promise<EspaceClientFournisseurEntree[]> {
  const response = await destinataireHttp.get<EspaceClientFournisseurEntree[]>("/fournisseurs");

  return response.data;
}

// §2 — sidebar "Paramètres" : DELETE /destinataire/compte (étape A),
// confirmation par mot de passe déjà exigée côté backend (Destinataire::ComptesController).
export async function supprimerCompte(motDePasse: string): Promise<void> {
  await destinataireHttp.delete("/compte", { data: { mot_de_passe: motDePasse } });
}
