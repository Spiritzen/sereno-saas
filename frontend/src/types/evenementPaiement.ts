import type { PaiementStatut } from "./paiement";

// Miroir de EvenementAvoir (mêmes clés, whitelist identique côté backend —
// EvenementPaiementBlueprint). Une seule source possible en v1 (registre
// purement local, aucune transmission).
export type EvenementPaiementSource = "interne";

export type EvenementPaiementActor = {
  id: string;
  display_name: string;
} | null;

export type EvenementPaiementDetails = {
  montant?: number;
  methode_code?: string;
  date_encaissement?: string;
};

export type EvenementPaiement = {
  id: string;
  statut: PaiementStatut;
  source: EvenementPaiementSource;
  created_at: string;
  actor: EvenementPaiementActor;
  details: EvenementPaiementDetails;
};
