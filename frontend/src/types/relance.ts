import type { Facture } from "./facture";

export type RelanceCanal = "email" | "courrier";
export type RelanceStatut = "planifiee" | "envoyee" | "echec";

export type Relance = {
  id: string;
  facture_id: string;
  canal: RelanceCanal;
  statut: RelanceStatut;
  destinataire_email: string | null;
  objet: string | null;
  // "letter_opener" en dev (mail rendu, non délivré), "smtp" en prod,
  // "test" en environnement de test — jamais recalculé côté front, c'est
  // la VÉRITÉ de ce qui s'est réellement passé (cf. RelanceService).
  mode_livraison: string | null;
  envoyee_at: string | null;
  created_at?: string | null;
};

// Réponse de POST /factures/:id/relances : la facture à jour est renvoyée
// avec la relance (derniere_relance_at/relances_count déjà à jour), pour
// éviter un refetch séparé après l'envoi.
export type RelanceResult = {
  relance: Relance;
  facture: Facture;
};
