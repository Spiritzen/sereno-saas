export type ConformiteItem = {
  cle?: string;
  key?: string;
  ok: boolean;
  message: string;
  niveau?: "erreur" | "warning" | "info";
};

export type ConformiteResult = {
  conforme: boolean;
  erreurs?: string[];
  avertissements?: string[];
  warnings?: string[];
  controles?: ConformiteItem[];
};