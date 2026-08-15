import type { FactureStatut, Money, StatutEncaissementLocal } from "./facture";
import type { LigneFacture } from "./ligneFacture";
import type { ClientType } from "./client";

// Portail destinataire (MVP) — types DISTINCTS de Facture/Client/Avoir : la
// vue publique n'expose jamais les mêmes champs (cf. PortailFactureBlueprint
// / PortailClientBlueprint / PortailAvoirBlueprint côté backend — aucun
// id interne autre que ceux nécessaires à l'affichage, aucun chemin de
// stockage, aucun signal CRM).
export type PortailClient = {
  id: string;
  type: ClientType;
  raison_sociale: string;
  siret: string | null;
  numero_tva: string | null;
  adresse_ligne1: string;
  adresse_ligne2: string | null;
  code_postal: string;
  ville: string;
  pays: string;
};

export type PortailFacture = {
  id: string;
  numero: string | null;
  type_document: "facture" | "acompte";
  statut: FactureStatut;
  total_ht: Money;
  total_tva: Money;
  total_ttc: Money;
  devise: string;
  mentions: string | null;
  conditions_paiement: string | null;
  date_emission: string | null;
  date_echeance: string | null;
  emise_at: string | null;
  pdf_disponible: boolean;
  reste_a_payer: Money;
  statut_encaissement_local: StatutEncaissementLocal;
  client: PortailClient | null;
  lignes_facture: LigneFacture[];
};

export type PortailAvoir = {
  id: string;
  numero: string | null;
  motif: string;
  statut: string;
  total_ht: Money;
  total_tva: Money;
  total_ttc: Money;
  date_emission: string | null;
  emis_at: string | null;
};
