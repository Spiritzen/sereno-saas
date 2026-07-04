export type ClientType = "entreprise" | "particulier" | "public";
export type ClientStatut = "actif" | "archive";

export type Client = {
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
  email: string | null;
  telephone: string | null;
  identifiant_routage_pa: string | null;
  statut: ClientStatut;
  notes: string | null;
  contacts_count?: number;
};

export type ClientInput = {
  type: ClientType;
  raison_sociale: string;
  siret?: string | null;
  numero_tva?: string | null;
  adresse_ligne1: string;
  adresse_ligne2?: string | null;
  code_postal: string;
  ville: string;
  pays?: string;
  email?: string | null;
  telephone?: string | null;
  identifiant_routage_pa?: string | null;
  notes?: string | null;
};
