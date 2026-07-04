import type { Money } from "./facture";

export type LigneFacture = {
  id: string;
  facture_id: string;
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

export type LigneFactureInput = {
  produit_id?: string | null;
  designation: string;
  quantite: number;
  prix_unitaire_ht: number;
  taux_tva: number;
  position?: number;
};

export type LigneFactureUpdateInput = Partial<LigneFactureInput>;
