import type { Money } from "./facture";

// Miroir de LigneFacture, MAIS ligne_avoir n'a ni montant_tva ni total_ttc
// en colonnes propres côté backend (cf. AvoirBlueprint/LigneAvoirBlueprint,
// V1.2a) : on ne type que ce qui existe réellement.
export type LigneAvoir = {
  id: string;
  avoir_id: string;
  designation: string;
  quantite: Money;
  prix_unitaire_ht: Money;
  taux_tva: Money;
  total_ht: Money;
  position: number;
};

export type LigneAvoirInput = {
  designation: string;
  quantite: number;
  prix_unitaire_ht: number;
  taux_tva: number;
  position?: number;
};

export type LigneAvoirUpdateInput = Partial<LigneAvoirInput>;
