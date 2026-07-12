export type TransmissionPaStatut =
  | "en_attente"
  | "depose"
  | "accepte"
  | "rejete"
  | "erreur";

export type TransmissionPa = {
  id: string;
  statut: TransmissionPaStatut;
  tentative: number;
  message_erreur: string | null;
  fournisseur: string;
  external_id: string | null;
  transmis_at: string | null;
  created_at: string;
  simulation: boolean;
};
