import type { FactureStatut } from "./facture";

export type EvenementFactureSource = "interne" | "pa" | "webhook";

export type EvenementFactureActor = {
  id: string;
  display_name: string;
} | null;

export type EvenementFactureDetails = {
  action?: string;
  numero?: string;
  date_emission?: string;
  emise_at?: string;
};

export type EvenementFacture = {
  id: string;
  statut: FactureStatut;
  source: EvenementFactureSource;
  code_statut_pa: string | null;
  created_at: string;
  actor: EvenementFactureActor;
  details: EvenementFactureDetails;
};
