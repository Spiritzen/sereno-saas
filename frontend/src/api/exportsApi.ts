import { http } from "./http";

const API_BASE_URL =
  import.meta.env.VITE_API_BASE_URL ?? "http://localhost:3000/api/v1";

export type FecApercu = {
  etiquette: string;
  nom_fichier: string;
};

// Export FEC (MVP) — aperçu léger (étiquette d'honnêteté + nom de fichier),
// à afficher AVANT le téléchargement (cf. §5/§6 execution_export_fec_mvp.txt).
export async function getFecApercu(debut: string, fin: string): Promise<FecApercu> {
  const response = await http.get<FecApercu>("/exports/fec/apercu", {
    params: { debut, fin },
  });

  return response.data;
}

// Même patron que getFacturePdfUrl (facturesApi.ts) : une URL brute ouverte
// via window.open — les cookies d'auth (HttpOnly) partent avec la
// navigation, pas besoin d'un fetch + blob.
export function getFecExportUrl(debut: string, fin: string) {
  const params = new URLSearchParams({ debut, fin });

  return `${API_BASE_URL}/exports/fec?${params.toString()}`;
}
