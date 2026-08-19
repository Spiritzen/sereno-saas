import type { PortailAvoir, PortailFacture } from "./portail";

// Espace client (C2) — types DÉDIÉS aux réponses de GET /destinataire/factures*
// (Destinataire::FacturesController). Réutilise PortailFacture/PortailAvoir
// TELS QUELS pour le détail (mêmes blueprints backend — PortailFactureBlueprint/
// PortailAvoirBlueprint) : jamais une 2e définition des mêmes champs.
export type EspaceClientOrganisation = {
  id: string;
  raison_sociale: string;
  logo_url: string | null;
};

// Vue LISTE légère (PortailFactureListeBlueprint côté backend) — sous-ensemble
// de PortailFacture : pas de lignes, pas de client imbriqué (le fournisseur
// est porté au niveau du groupe, pas de la facture).
export type EspaceClientFactureListe = Pick<
  PortailFacture,
  | "id"
  | "numero"
  | "statut"
  | "total_ttc"
  | "devise"
  | "date_emission"
  | "date_echeance"
  | "reste_a_payer"
  | "statut_encaissement_local"
>;

export type EspaceClientGroupeFournisseur = {
  fournisseur: EspaceClientOrganisation;
  factures: EspaceClientFactureListe[];
};

// execution_espace_client_sidebar_pagination_badge.txt §3 — métadonnées de
// pagination RÉELLE renvoyées par Destinataire::FacturesController#index
// (jamais un simple masquage côté écran : `groupes` ne contient QUE la page
// demandée, `pagination` porte de quoi naviguer).
export type EspaceClientPagination = {
  page: number;
  par_page: number;
  total: number;
  total_pages: number;
};

export type EspaceClientFacturesReponse = {
  groupes: EspaceClientGroupeFournisseur[];
  pagination: EspaceClientPagination;
};

export type EspaceClientFactureDetail = {
  facture: PortailFacture;
  fournisseur: EspaceClientOrganisation;
  avoirs: PortailAvoir[];
};

// §2 — sidebar "Mes fournisseurs" (Destinataire::FournisseursController).
export type EspaceClientFournisseurEntree = {
  fournisseur: EspaceClientOrganisation;
  nombre_factures: number;
};

export type FiltreStatutPaiement = "" | "en_attente" | "payee";
export type TriFactures = "date_desc" | "date_asc" | "montant_desc" | "montant_asc";

export type ListerFacturesParams = {
  q?: string;
  statut?: FiltreStatutPaiement;
  tri?: TriFactures;
  fournisseur_id?: string;
  page?: number;
};
