import type { FactureStatut } from "./facture";

export type TransmissionPaStatut =
  | "en_attente"
  | "depose"
  | "accepte"
  | "rejete"
  | "erreur";

export type TransmissionPa = {
  id: string;
  statut: TransmissionPaStatut;
  tentative: number;
  message_erreur: string | null;
  fournisseur: string;
  external_id: string | null;
  transmis_at: string | null;
  created_at: string;
  simulation: boolean;
  // V1.1-B3.1b — polling automatique.
  next_poll_at: string | null;
  polling_paused: boolean;
  polling_stopped: boolean;
  polling_stop_reason: string | null;
};

// Les 5 issues possibles d'une synchronisation : toutes NORMALES, aucune
// n'est une erreur technique (celle-ci remonte en 502, voir
// getTransmissionFromError / le catch dédié côté page).
export type PaSyncResultat =
  | "applied"
  | "duplicate"
  | "stale"
  | "requires_review"
  | "unmapped";

export type PaSyncResult = {
  resultat: PaSyncResultat;
  motif: string | null;
  statut_facture_avant: FactureStatut;
  statut_facture_apres: FactureStatut;
  transmission: TransmissionPa;
};
