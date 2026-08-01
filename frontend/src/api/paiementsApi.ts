import type { Paiement, PaiementInput } from "../types/paiement";
import { http } from "./http";
import { normalizeCollection, normalizeResource } from "./normalize";

// Calqué sur avoirsApi. Routes NICHÉES sous factures (décision étage B) :
// jamais de route à plat pour les paiements.
export async function listPaiements(factureId: string): Promise<Paiement[]> {
  const response = await http.get<unknown>(`/factures/${factureId}/paiements`);

  return normalizeCollection<Paiement>(response.data, "paiements");
}

export async function createPaiement(
  factureId: string,
  input: PaiementInput,
): Promise<Paiement> {
  const response = await http.post<unknown>(`/factures/${factureId}/paiements`, {
    paiement: input,
  });

  return normalizeResource<Paiement>(response.data, "paiement");
}

export async function confirmerPaiement(
  factureId: string,
  paiementId: string,
): Promise<Paiement> {
  const response = await http.post<unknown>(
    `/factures/${factureId}/paiements/${paiementId}/confirmer`,
  );

  return normalizeResource<Paiement>(response.data, "paiement");
}

export async function annulerPaiement(
  factureId: string,
  paiementId: string,
): Promise<Paiement> {
  const response = await http.post<unknown>(
    `/factures/${factureId}/paiements/${paiementId}/annuler`,
  );

  return normalizeResource<Paiement>(response.data, "paiement");
}

// Garde-fou de montant CUMULÉ, même patron que sommeAvoirsDejaEmis : le
// backend fait foi sur chaque montant individuel, cette fonction n'invente
// rien, elle additionne ce qui est déjà confirmé. Seuls les paiements
// CONFIRMÉS comptent (brouillon/annulé exclus) — non utilisé pour le
// "reste à payer" affiché (dérivé du backend, cf. FactureBlueprint), utile
// uniquement si le frontend a besoin d'un total local d'appoint.
export function sommePaiementsConfirmes(paiements: Paiement[]): number {
  return paiements
    .filter((paiement) => paiement.statut === "confirme")
    .reduce((total, paiement) => total + Number(paiement.montant ?? 0), 0);
}
