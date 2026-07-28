import type { FactureStatut, Money } from "./facture";
import type { LigneAvoir } from "./ligneAvoir";
import type { Client } from "./client";

// Les statuts d'un avoir sont EXACTEMENT les mêmes chaînes que ceux d'une
// facture (Avoir::STATUTS == Facture::STATUTS côté backend) : un alias, pas
// une redéfinition, pour que les composants déjà typés en FactureStatut
// (InvoiceDetailHeader, InvoiceTransmissionSection...) acceptent un avoir
// sans modification.
export type AvoirStatut = FactureStatut;

export type Avoir = {
  id: string;
  client_id: string;
  facture_id: string;
  facture_numero: string | null;
  numero: string | null;
  motif: string;
  statut: AvoirStatut;
  total_ht: Money;
  total_tva: Money;
  total_ttc: Money;
  pdf_url: string | null;
  xml_url: string | null;
  date_emission: string | null;
  emis_at: string | null;
  created_at?: string | null;
  updated_at?: string | null;
  client?: Pick<
    Client,
    "id" | "raison_sociale" | "siret" | "identifiant_routage_pa" | "email" | "ville" | "pays" | "type"
  > | null;
  lignes_avoir?: LigneAvoir[];
};

export type AvoirInput = {
  facture_id: string;
  motif: string;
};
