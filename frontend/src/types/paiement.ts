import type { Money } from "./facture";

// Codes UNTDID 4461 retenus côté backend (Paiement::MOYENS) — le libellé est
// DÉRIVÉ par le backend (methode_libelle), jamais recalculé ici.
export type PaiementMethodeCode = "10" | "20" | "48" | "58" | "59";

export type PaiementStatut = "brouillon" | "confirme" | "annule";

export type Paiement = {
  id: string;
  facture_id: string;
  montant: Money;
  methode_code: PaiementMethodeCode;
  methode_libelle: string;
  date_encaissement: string | null;
  reference: string | null;
  statut: PaiementStatut;
  created_at?: string | null;
  updated_at?: string | null;
};

export type PaiementInput = {
  montant: number;
  methode_code: PaiementMethodeCode;
  date_encaissement: string;
  reference?: string;
};

export const MOYENS_PAIEMENT: { code: PaiementMethodeCode; libelle: string }[] = [
  { code: "58", libelle: "Virement SEPA" },
  { code: "20", libelle: "Chèque" },
  { code: "10", libelle: "Espèces" },
  { code: "48", libelle: "Carte bancaire" },
  { code: "59", libelle: "Prélèvement SEPA" },
];
