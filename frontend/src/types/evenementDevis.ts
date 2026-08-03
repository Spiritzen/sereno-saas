import type { DevisStatut } from "./devis";

// Un devis n'a aucun canal externe : source toujours "interne" (miroir de
// EvenementPaiement, cf. backend).
export type EvenementDevisSource = "interne";

export type EvenementDevisActor = {
  id: string;
  display_name: string;
} | null;

// La whitelist backend (EvenementDevisBlueprint) filtre le payload PAR
// ACTION, pas par statut — "devis_accepte" et "devis_converti" partagent le
// même `statut` ("accepte") mais des payloads différents. `action` est donc
// la clé de lecture, jamais `statut` seul.
export type EvenementDevisAction =
  | "devis_envoye"
  | "devis_accepte"
  | "devis_refuse"
  | "devis_converti";

export type EvenementDevisDetails = {
  action?: EvenementDevisAction;
  numero?: string;
  facture_id?: string;
  facture_numero?: string;
};

export type EvenementDevis = {
  id: string;
  statut: DevisStatut;
  source: EvenementDevisSource;
  created_at: string;
  actor: EvenementDevisActor;
  details: EvenementDevisDetails;
};
