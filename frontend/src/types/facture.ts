import type { Client } from "./client";
import type { LigneFacture } from "./ligneFacture";

export type Money = string | number;

export type FactureStatut =
  | "brouillon"
  | "emise"
  | "deposee"
  | "recue"
  | "mise_a_disposition"
  | "approuvee"
  | "refusee"
  | "en_litige"
  | "encaissee"
  | "archivee"
  | "annulee";

export type Facture = {
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
  type_document: "facture" | "acompte";
  statut: FactureStatut;
  date_emission: string | null;
  date_echeance: string | null;
  total_ht: Money;
  total_tva: Money;
  total_ttc: Money;
  devise: string;
  format: "factur_x" | "ubl" | "cii";
  mentions: string | null;
  conditions_paiement: string | null;
  pdf_url: string | null;
  xml_url: string | null;
  emise_at: string | null;
  created_at?: string | null;
  lignes_facture?: LigneFacture[];
};

export type FactureInput = {
  client_id: string;
  date_echeance?: string | null;
  mentions?: string | null;
  conditions_paiement?: string | null;
};

export type FactureUpdateInput = Partial<FactureInput>;
