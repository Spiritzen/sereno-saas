import type { Client } from "../types/client";
import type { Facture } from "../types/facture";

// D1 execution_dashboard_d1_cockpit_final_sereno.txt §3/§5 — module de
// calcul PUR, testable indépendamment des composants React. Reprend les
// helpers déjà présents dans DashboardPage.tsx (aucune 2e définition d'une
// règle métier déjà tranchée), corrige les LIBELLÉS qui surinterprétaient
// les données (§3), et ajoute UNIQUEMENT ce qui reste dérivable honnêtement
// des données déjà chargées (listFactures/listClients) — jamais un nouvel
// appel API, jamais un N+1 (aucun listPaiements par facture).
//
// `today` est TOUJOURS un paramètre explicite (jamais `new Date()` interne
// à ces fonctions) : les tests contrôlent l'horloge, la fonction reste pure.

// D1.1 (prompt_claude_code_dashboard_d1_1_regulation_grille_etats_reseau.txt
// §5) — simple alias de typage (aucune règle métier), placé ici pour éviter
// un import circulaire pages/DashboardPage.tsx <-> components/dashboard/*
// puisque les deux dépendent déjà de ce module. LOADING/ERROR ne doivent
// jamais être convertis implicitement en READY + EMPTY par un composant.
export type DashboardStatus = "loading" | "error" | "ready";

// ---------------------------------------------------------------------------
// Helpers de base — repris tels quels de l'ancien DashboardPage.tsx
// ---------------------------------------------------------------------------

export function toNumber(value: string | number | null | undefined): number {
  const parsed = Number(value ?? 0);

  return Number.isFinite(parsed) ? parsed : 0;
}

export function getFactureTotalTtc(facture: Facture): number {
  return toNumber(facture.total_ttc);
}

// Exclut les brouillons vides / lignes non renseignées (total 0) des
// agrégats financiers — même filtre qu'avant, jamais relâché.
export function isFactureMetier(facture: Facture): boolean {
  return getFactureTotalTtc(facture) > 0;
}

export function isFactureEmise(facture: Facture): boolean {
  return facture.statut !== "brouillon";
}

export function isFactureEnAttente(facture: Facture): boolean {
  return [
    "emise",
    "deposee",
    "recue",
    "mise_a_disposition",
    "approuvee",
    "en_litige",
  ].includes(facture.statut);
}

export function isFactureEnRetard(facture: Facture, today: Date): boolean {
  if (!isFactureMetier(facture)) {
    return false;
  }

  if (!isFactureEnAttente(facture)) {
    return false;
  }

  if (!facture.date_echeance) {
    return false;
  }

  const reference = startOfDay(today);
  const dateEcheance = startOfDay(new Date(facture.date_echeance));

  return dateEcheance < reference;
}

export function hasDateEcheance(
  facture: Facture,
): facture is Facture & { date_echeance: string } {
  return Boolean(facture.date_echeance);
}

export function getClientName(
  facture: Facture,
  clientsById: Record<string, Client>,
): string {
  if (facture.client?.raison_sociale) {
    return facture.client.raison_sociale;
  }

  const client = clientsById[facture.client_id];

  if (client?.raison_sociale) {
    return client.raison_sociale;
  }

  return `Client ${facture.client_id.slice(0, 8)}`;
}

export function formatFactureFormat(format: Facture["format"]): string {
  const labels = {
    factur_x: "Factur-X",
    ubl: "UBL",
    cii: "CII",
  };

  return labels[format] ?? format;
}

export function formatCurrency(value: number): string {
  const hasCents = Math.abs(value % 1) > 0;

  return new Intl.NumberFormat("fr-FR", {
    style: "currency",
    currency: "EUR",
    minimumFractionDigits: hasCents ? 2 : 0,
    maximumFractionDigits: hasCents ? 2 : 0,
  }).format(value);
}

export function formatToday(today: Date): string {
  return new Intl.DateTimeFormat("fr-FR", {
    weekday: "long",
    day: "numeric",
    month: "long",
    year: "numeric",
  }).format(today);
}

export function buildGreeting(prenom: string | undefined): string {
  return prenom ? `Bonjour ${prenom}` : "Bonjour";
}

export function computeJoursRestants(echeance: Date, today: Date): number {
  const diffMs = startOfDay(echeance).getTime() - startOfDay(today).getTime();

  return Math.ceil(diffMs / (1000 * 60 * 60 * 24));
}

export function formatEcheanceLabel(value: string | null): string {
  if (!value) {
    return "Échéance";
  }

  return new Intl.DateTimeFormat("fr-FR", {
    day: "2-digit",
    month: "short",
  }).format(new Date(value));
}

function startOfDay(date: Date): Date {
  const copy = new Date(date);
  copy.setHours(0, 0, 0, 0);

  return copy;
}

function dateKey(date: Date): string {
  const d = startOfDay(date);

  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

// ---------------------------------------------------------------------------
// §3 — KPI honnêtes (corrige les libellés trompeurs de l'ancienne version)
// ---------------------------------------------------------------------------

export type KpiEncaissementConstate = { total: number; count: number };
export type KpiEnAttente = { total: number; count: number };
export type KpiEnRetard = { total: number; count: number };
// ratio=null quand AUCUNE facture émise (jamais 100% par défaut, §3.4).
export type KpiCompletude = { ratio: number | null; completes: number; emises: number };

export type DashboardKpis = {
  encaissementConstate: KpiEncaissementConstate;
  enAttente: KpiEnAttente;
  enRetard: KpiEnRetard;
  completude: KpiCompletude;
};

export function buildDashboardKpis(factures: Facture[], today: Date): DashboardKpis {
  const facturesMetier = factures.filter(isFactureMetier);

  // §3.1 — "Encaissement constaté" : UNIQUEMENT le statut réglementaire
  // facture.statut === "encaissee" (PA), jamais le suivi local des
  // Paiement (indisponible sans N+1 sur la liste, cf. reconnaissance §2.3).
  // Jamais renommé "réel" : c'est un statut déclaratif, pas une preuve de
  // caisse.
  const facturesEncaissees = facturesMetier.filter((f) => f.statut === "encaissee");
  const encaissementConstate: KpiEncaissementConstate = {
    total: facturesEncaissees.reduce((sum, f) => sum + getFactureTotalTtc(f), 0),
    count: facturesEncaissees.length,
  };

  // §3.3 — retard AVANT attente (même exclusion mutuelle qu'avant : une
  // facture en retard ne compte jamais aussi dans "en attente").
  const facturesEnRetard = facturesMetier.filter((f) => isFactureEnRetard(f, today));
  const enRetard: KpiEnRetard = {
    total: facturesEnRetard.reduce((sum, f) => sum + getFactureTotalTtc(f), 0),
    count: facturesEnRetard.length,
  };

  // §3.2 — jamais présenté comme un "reste à payer" (donnée indisponible en
  // liste) : c'est la somme TTC des factures en cours, hors échues.
  const facturesEnAttenteHorsRetard = facturesMetier.filter(
    (f) => isFactureEnAttente(f) && !isFactureEnRetard(f, today),
  );
  const enAttente: KpiEnAttente = {
    total: facturesEnAttenteHorsRetard.reduce((sum, f) => sum + getFactureTotalTtc(f), 0),
    count: facturesEnAttenteHorsRetard.length,
  };

  // §3.4 — "Complétude" (jamais "Conformité") : ratio des factures NON
  // BROUILLON portant réellement pdf_url ET xml_url. ratio=null si aucune
  // facture émise (jamais 100% par défaut).
  const facturesEmises = facturesMetier.filter(isFactureEmise);
  const facturesCompletes = facturesEmises.filter(
    (f) => Boolean(f.pdf_url) && Boolean(f.xml_url),
  );
  const completude: KpiCompletude = {
    ratio:
      facturesEmises.length === 0
        ? null
        : Math.round((facturesCompletes.length / facturesEmises.length) * 100),
    completes: facturesCompletes.length,
    emises: facturesEmises.length,
  };

  return { encaissementConstate, enAttente, enRetard, completude };
}

// ---------------------------------------------------------------------------
// §4.F — Échéances (right rail) : MÊME logique d'éligibilité que les KPI,
// jamais une 2e définition du retard.
// ---------------------------------------------------------------------------

export type EcheanceItem = {
  facture: Facture;
  enRetard: boolean;
};

export function buildEcheancesAVenir(
  factures: Facture[],
  limit: number,
  today: Date,
): EcheanceItem[] {
  return factures
    .filter(isFactureMetier)
    .filter(isFactureEnAttente)
    .filter(hasDateEcheance)
    .sort(
      (a, b) => new Date(a.date_echeance).getTime() - new Date(b.date_echeance).getTime(),
    )
    .slice(0, limit)
    .map((facture) => ({ facture, enRetard: isFactureEnRetard(facture, today) }));
}

// ---------------------------------------------------------------------------
// §4.F — mini-calendrier du mois courant : une VUE de dates réelles, pas un
// moteur métier (réutilise isFactureEnRetard/isFactureMetier ci-dessus,
// jamais une 3e définition du retard). Semaine française lundi→dimanche,
// nombre de lignes variable selon le mois (jamais un padding arbitraire à
// 6 semaines fixes).
// ---------------------------------------------------------------------------

export type CalendarDay = {
  date: Date;
  isCurrentMonth: boolean;
  isToday: boolean;
  hasEcheance: boolean;
  hasEcheanceEnRetard: boolean;
};

export type CalendarMonth = {
  year: number;
  month: number;
  label: string;
  weekdays: string[];
  weeks: CalendarDay[][];
};

const JOURS_SEMAINE_FR = ["L", "M", "M", "J", "V", "S", "D"];

function capitalize(value: string): string {
  return value.length === 0 ? value : value.charAt(0).toUpperCase() + value.slice(1);
}

export function buildCalendarMonth(factures: Facture[], today: Date): CalendarMonth {
  const reference = startOfDay(today);
  const year = reference.getFullYear();
  const month = reference.getMonth();

  const firstOfMonth = new Date(year, month, 1);
  const lastOfMonth = new Date(year, month + 1, 0);

  // getDay() : dimanche=0..samedi=6 → converti en lundi=0..dimanche=6.
  const firstWeekdayMonBased = (firstOfMonth.getDay() + 6) % 7;
  const lastWeekdayMonBased = (lastOfMonth.getDay() + 6) % 7;

  const gridStart = new Date(year, month, 1 - firstWeekdayMonBased);
  const gridEnd = new Date(year, month, lastOfMonth.getDate() + (6 - lastWeekdayMonBased));

  const marqueursParJour = new Map<string, { hasEcheance: boolean; hasEcheanceEnRetard: boolean }>();

  factures
    .filter(isFactureMetier)
    .filter(hasDateEcheance)
    .forEach((facture) => {
      const key = dateKey(new Date(facture.date_echeance));
      const entree = marqueursParJour.get(key) ?? { hasEcheance: false, hasEcheanceEnRetard: false };

      entree.hasEcheance = true;

      if (isFactureEnRetard(facture, reference)) {
        entree.hasEcheanceEnRetard = true;
      }

      marqueursParJour.set(key, entree);
    });

  const days: CalendarDay[] = [];
  const cursor = new Date(gridStart);

  while (cursor <= gridEnd) {
    const key = dateKey(cursor);
    const marqueur = marqueursParJour.get(key);

    days.push({
      date: new Date(cursor),
      isCurrentMonth: cursor.getMonth() === month,
      isToday: key === dateKey(reference),
      hasEcheance: Boolean(marqueur?.hasEcheance),
      hasEcheanceEnRetard: Boolean(marqueur?.hasEcheanceEnRetard),
    });

    cursor.setDate(cursor.getDate() + 1);
  }

  const weeks: CalendarDay[][] = [];

  for (let i = 0; i < days.length; i += 7) {
    weeks.push(days.slice(i, i + 7));
  }

  return {
    year,
    month,
    label: capitalize(
      new Intl.DateTimeFormat("fr-FR", { month: "long", year: "numeric" }).format(firstOfMonth),
    ),
    weekdays: JOURS_SEMAINE_FR,
    weeks,
  };
}

// ---------------------------------------------------------------------------
// §4.G — « À traiter » : catégories fiables uniquement, dérivées des
// factures déjà chargées. Jamais une date relative inventée, jamais un
// flux d'activité cross-document (aucun endpoint ne l'expose).
// ---------------------------------------------------------------------------

export type AttentionCategory =
  | "brouillons"
  | "en_retard"
  | "refusees_litige"
  | "artefacts_manquants";

export type AttentionItem = {
  category: AttentionCategory;
  label: string;
  count: number;
};

export function buildAttentionItems(factures: Facture[], today: Date): AttentionItem[] {
  const facturesMetier = factures.filter(isFactureMetier);

  // Brouillons : PAS filtrés par isFactureMetier — un brouillon encore
  // vide (aucune ligne, total 0) reste un document réel à reprendre, pas
  // un artefact à ignorer.
  const brouillons = factures.filter((f) => f.statut === "brouillon").length;
  const enRetard = facturesMetier.filter((f) => isFactureEnRetard(f, today)).length;
  const refuseesLitige = facturesMetier.filter(
    (f) => f.statut === "refusee" || f.statut === "en_litige",
  ).length;
  const artefactsManquants = facturesMetier
    .filter(isFactureEmise)
    .filter((f) => !(f.pdf_url && f.xml_url)).length;

  const items: AttentionItem[] = [];

  if (brouillons > 0) {
    items.push({ category: "brouillons", label: "Brouillon à reprendre", count: brouillons });
  }

  if (enRetard > 0) {
    items.push({ category: "en_retard", label: "Facture en retard", count: enRetard });
  }

  if (refuseesLitige > 0) {
    items.push({
      category: "refusees_litige",
      label: "Refusée ou en litige",
      count: refuseesLitige,
    });
  }

  if (artefactsManquants > 0) {
    items.push({
      category: "artefacts_manquants",
      label: "Émise sans PDF + XML",
      count: artefactsManquants,
    });
  }

  return items;
}

// ---------------------------------------------------------------------------
// §4.E — tri déterministe des factures récentes. L'API (Api::V1::FacturesController#index)
// trie déjà `order(created_at: :desc)`, mais on re-trie explicitement ici
// (défensif, jamais coûteux sur une page de facture) plutôt que de dépendre
// silencieusement d'une garantie non documentée côté frontend — fallback
// sur emise_at si created_at est absent (ne casse jamais sur une valeur
// manquante).
// ---------------------------------------------------------------------------

export function buildRecentFactures(factures: Facture[], limit: number): Facture[] {
  return [...factures]
    .sort((a, b) => {
      const dateA = a.created_at ?? a.emise_at ?? "";
      const dateB = b.created_at ?? b.emise_at ?? "";

      return dateB.localeCompare(dateA);
    })
    .slice(0, limit);
}
