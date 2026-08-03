import type { Client } from "./client";
import type { Money } from "./facture";
import type { LigneDevis } from "./ligneDevis";

// Machine à états réelle (DevisStatutService::TRANSITIONS, backend) :
// brouillon -> envoye -> accepte / refuse. Pas de 5e statut "converti" — la
// conversion est un booléen DÉRIVÉ (cf. `converti` ci-dessous), jamais un
// statut stocké.
export type DevisStatut = "brouillon" | "envoye" | "accepte" | "refuse";

export type DevisFactureGeneree = {
  id: string;
  numero: string | null;
};

export type Devis = {
  id: string;
  client_id: string;
  client?: Pick<
    Client,
    | "id"
    | "raison_sociale"
    | "siret"
    | "identifiant_routage_pa"
    | "email"
    | "ville"
    | "pays"
    | "type"
  > | null;
  numero: string | null;
  objet: string | null;
  statut: DevisStatut;
  total_ht: Money;
  total_tva: Money;
  total_ttc: Money;
  conditions: string | null;
  date_emission: string | null;
  date_validite: string | null;
  // Dérivés côté backend (Devis#expire?/#converti?) — jamais stockés, jamais
  // recalculés côté front.
  expire: boolean;
  converti: boolean;
  facture_generee: DevisFactureGeneree | null;
  created_at?: string | null;
  updated_at?: string | null;
  lignes_count?: number;
  lignes_devis?: LigneDevis[];
};

export type DevisInput = {
  client_id: string;
  objet?: string | null;
  date_emission?: string | null;
  date_validite?: string | null;
  conditions?: string | null;
};

export type DevisUpdateInput = Partial<DevisInput>;
