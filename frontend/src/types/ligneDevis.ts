import type { Money } from "./facture";

// Miroir de LigneFacture : ligne_devis a montant_tva/total_ttc par ligne
// depuis l'étage A (branchée sur FactureTotalsService côté backend).
export type LigneDevis = {
  id: string;
  devis_id: string;
  produit_id: string | null;
  designation: string;
  quantite: Money;
  prix_unitaire_ht: Money;
  taux_tva: Money;
  montant_tva: Money;
  total_ht: Money;
  total_ttc: Money;
  position: number;
};

export type LigneDevisInput = {
  designation: string;
  quantite: number;
  prix_unitaire_ht: number;
  taux_tva: number;
  position?: number;
};

export type LigneDevisUpdateInput = Partial<LigneDevisInput>;
