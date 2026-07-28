import type { AvoirStatut } from "./avoir";

// Miroir exact de EvenementFacture (mêmes clés, whitelist identique côté
// backend — EvenementAvoirBlueprint).
export type EvenementAvoirSource = "interne" | "pa" | "webhook" | "sandbox";

export type EvenementAvoirActor = {
  id: string;
  display_name: string;
} | null;

export type EvenementAvoirDetails = {
  action?: string;
  numero?: string;
  date_emission?: string;
  emis_at?: string;
};

export type EvenementAvoir = {
  id: string;
  statut: AvoirStatut;
  source: EvenementAvoirSource;
  code_statut_pa: string | null;
  created_at: string;
  actor: EvenementAvoirActor;
  details: EvenementAvoirDetails;
};
