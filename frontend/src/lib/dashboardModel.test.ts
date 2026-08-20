import { describe, expect, it } from "vitest";
import type { Facture, FactureStatut } from "../types/facture";
import {
  buildAttentionItems,
  buildCalendarMonth,
  buildDashboardKpis,
  buildEcheancesAVenir,
  buildRecentFactures,
  computeJoursRestants,
  formatCurrency,
  formatEcheanceLabel,
  getClientName,
  isFactureEnRetard,
} from "./dashboardModel";

const TODAY = new Date("2026-08-20T10:00:00");

let sequence = 0;

function facture(overrides: Partial<Facture> = {}): Facture {
  sequence += 1;

  return {
    id: `fac-${sequence}`,
    client_id: `cli-${sequence}`,
    client: null,
    numero: `FAC-${sequence}`,
    type_document: "facture",
    statut: "emise" as FactureStatut,
    date_emission: "2026-08-01",
    date_echeance: "2026-08-31",
    total_ht: "100.00",
    total_tva: "20.00",
    total_ttc: "120.00",
    devise: "EUR",
    format: "factur_x",
    mentions: null,
    conditions_paiement: null,
    pdf_url: "/storage/factures/x/facture.pdf",
    xml_url: "/storage/factures/x/facture.xml",
    emise_at: "2026-08-01T10:00:00Z",
    created_at: "2026-08-01T10:00:00Z",
    ...overrides,
  };
}

describe("dashboardModel — formatage robuste", () => {
  it("formatCurrency gère 0 sans planter", () => {
    expect(formatCurrency(0)).toContain("0");
  });

  it("formatEcheanceLabel gère une date null", () => {
    expect(formatEcheanceLabel(null)).toBe("Échéance");
  });

  it("getClientName retombe sur un nom générique si rien n'est disponible", () => {
    const f = facture({ client_id: "abcdef1234567890", client: null });
    expect(getClientName(f, {})).toBe("Client abcdef12");
  });

  it("computeJoursRestants est déterministe (today explicite, jamais Date.now())", () => {
    expect(computeJoursRestants(new Date("2026-09-01"), new Date("2026-08-20"))).toBe(12);
    expect(computeJoursRestants(new Date("2026-08-20"), new Date("2026-08-25"))).toBeLessThan(0);
  });
});

describe("dashboardModel — buildDashboardKpis (§3, KPI honnêtes)", () => {
  it("encaissement constaté : somme UNIQUEMENT les factures statut=encaissee, jamais un suivi de paiement local", () => {
    const factures = [
      facture({ statut: "encaissee", total_ttc: "500" }),
      facture({ statut: "encaissee", total_ttc: "300" }),
      facture({ statut: "emise", total_ttc: "999" }), // ne compte PAS
    ];

    const kpis = buildDashboardKpis(factures, TODAY);

    expect(kpis.encaissementConstate.total).toBe(800);
    expect(kpis.encaissementConstate.count).toBe(2);
  });

  it("en attente : exclut les factures en retard (mutuellement exclusif)", () => {
    const factures = [
      facture({ statut: "emise", date_echeance: "2026-09-01", total_ttc: "100" }), // à venir
      facture({ statut: "emise", date_echeance: "2026-08-01", total_ttc: "200" }), // en retard -> exclu d'"en attente"
    ];

    const kpis = buildDashboardKpis(factures, TODAY);

    expect(kpis.enAttente.total).toBe(100);
    expect(kpis.enAttente.count).toBe(1);
    expect(kpis.enRetard.total).toBe(200);
    expect(kpis.enRetard.count).toBe(1);
  });

  it("retard : dérivé du statut éligible ET d'une date_echeance strictement antérieure à aujourd'hui", () => {
    const enRetard = facture({ statut: "deposee", date_echeance: "2026-08-19", total_ttc: "50" });
    const pasEncoreEchue = facture({ statut: "deposee", date_echeance: "2026-08-20", total_ttc: "50" }); // = today, PAS en retard
    const brouillon = facture({ statut: "brouillon", date_echeance: "2026-01-01", total_ttc: "50" }); // pas éligible

    expect(isFactureEnRetard(enRetard, TODAY)).toBe(true);
    expect(isFactureEnRetard(pasEncoreEchue, TODAY)).toBe(false);
    expect(isFactureEnRetard(brouillon, TODAY)).toBe(false);
  });

  it("exclut les brouillons et les factures non-métier (total 0) des agrégats financiers", () => {
    const factures = [
      facture({ statut: "brouillon", total_ttc: "0" }),
      facture({ statut: "emise", total_ttc: "0" }), // total 0 -> non-métier, exclu
      facture({ statut: "annulee", date_echeance: "2026-01-01", total_ttc: "999" }), // statut non éligible "attente"
    ];

    const kpis = buildDashboardKpis(factures, TODAY);

    expect(kpis.enAttente.count).toBe(0);
    expect(kpis.enRetard.count).toBe(0);
    expect(kpis.encaissementConstate.count).toBe(0);
  });

  it("complétude : ratio des factures ÉMISES portant réellement pdf_url ET xml_url", () => {
    const factures = [
      facture({ statut: "emise", pdf_url: "a.pdf", xml_url: "a.xml" }),
      facture({ statut: "emise", pdf_url: "b.pdf", xml_url: "b.xml" }),
      facture({ statut: "emise", pdf_url: null, xml_url: "c.xml" }), // incomplet
      facture({ statut: "brouillon", pdf_url: null, xml_url: null }), // hors périmètre (brouillon)
    ];

    const kpis = buildDashboardKpis(factures, TODAY);

    expect(kpis.completude.emises).toBe(3);
    expect(kpis.completude.completes).toBe(2);
    expect(kpis.completude.ratio).toBe(67);
  });

  it("aucune facture émise -> complétude neutre (ratio null), JAMAIS 100%", () => {
    const factures = [facture({ statut: "brouillon", total_ttc: "0" })];

    const kpis = buildDashboardKpis(factures, TODAY);

    expect(kpis.completude.ratio).toBeNull();
    expect(kpis.completude.emises).toBe(0);
  });

  it("liste vide -> tous les KPI à zéro, jamais une erreur", () => {
    const kpis = buildDashboardKpis([], TODAY);

    expect(kpis.encaissementConstate).toEqual({ total: 0, count: 0 });
    expect(kpis.enAttente).toEqual({ total: 0, count: 0 });
    expect(kpis.enRetard).toEqual({ total: 0, count: 0 });
    expect(kpis.completude.ratio).toBeNull();
  });
});

describe("dashboardModel — buildEcheancesAVenir", () => {
  it("trie par proximité et respecte la limite demandée", () => {
    const factures = [
      facture({ id: "loin", statut: "emise", date_echeance: "2026-12-01" }),
      facture({ id: "proche", statut: "emise", date_echeance: "2026-08-25" }),
      facture({ id: "moyen", statut: "emise", date_echeance: "2026-09-15" }),
    ];

    const echeances = buildEcheancesAVenir(factures, 2, TODAY);

    expect(echeances).toHaveLength(2);
    expect(echeances[0].facture.date_echeance).toBe("2026-08-25");
    expect(echeances[1].facture.date_echeance).toBe("2026-09-15");
  });

  it("ignore les factures sans date_echeance (jamais une date fictive)", () => {
    const factures = [facture({ statut: "emise", date_echeance: null })];

    expect(buildEcheancesAVenir(factures, 5, TODAY)).toEqual([]);
  });
});

describe("dashboardModel — buildCalendarMonth", () => {
  it("marque uniquement les jours portant réellement une échéance", () => {
    const factures = [facture({ statut: "emise", date_echeance: "2026-08-25" })];

    const calendrier = buildCalendarMonth(factures, TODAY);
    const jours = calendrier.weeks.flat();
    const jourMarque = jours.find((j) => j.date.getDate() === 25 && j.isCurrentMonth);
    const jourVoisin = jours.find((j) => j.date.getDate() === 24 && j.isCurrentMonth);

    expect(jourMarque?.hasEcheance).toBe(true);
    expect(jourVoisin?.hasEcheance).toBe(false);
  });

  it("distingue échéance en retard (rouge) d'échéance à venir", () => {
    const factures = [facture({ statut: "emise", date_echeance: "2026-08-01" })]; // avant TODAY -> en retard

    const calendrier = buildCalendarMonth(factures, TODAY);
    const jour = calendrier.weeks.flat().find((j) => j.date.getDate() === 1 && j.isCurrentMonth);

    expect(jour?.hasEcheance).toBe(true);
    expect(jour?.hasEcheanceEnRetard).toBe(true);
  });

  it("identifie 'aujourd'hui' correctement", () => {
    const calendrier = buildCalendarMonth([], TODAY);
    const aujourdhui = calendrier.weeks.flat().find((j) => j.isToday);

    expect(aujourdhui?.date.getDate()).toBe(20);
    expect(aujourdhui?.isCurrentMonth).toBe(true);
  });

  it("semaine commence un LUNDI (convention française)", () => {
    const calendrier = buildCalendarMonth([], TODAY);

    expect(calendrier.weekdays[0]).toBe("L");
    expect(calendrier.weekdays[6]).toBe("D");
    expect(calendrier.weeks[0][0].date.getDay()).toBe(1); // 1 = lundi en JS
  });

  it("aucune échéance ce mois -> calendrier valide, aucun jour marqué", () => {
    const calendrier = buildCalendarMonth([], TODAY);

    expect(calendrier.weeks.flat().every((j) => !j.hasEcheance)).toBe(true);
    expect(calendrier.label).toContain("2026");
  });
});

describe("dashboardModel — buildAttentionItems", () => {
  it("compte les brouillons MÊME vides (total 0), en attente d'être repris", () => {
    const factures = [facture({ statut: "brouillon", total_ttc: "0" })];

    const items = buildAttentionItems(factures, TODAY);

    expect(items).toContainEqual({ category: "brouillons", label: "Brouillon à reprendre", count: 1 });
  });

  it("catégorise retard, refusé/litige et artefacts manquants séparément", () => {
    const factures = [
      facture({ statut: "emise", date_echeance: "2026-01-01" }), // en retard
      facture({ statut: "refusee" }),
      facture({ statut: "en_litige" }),
      facture({ statut: "emise", pdf_url: null, xml_url: null }),
    ];

    const items = buildAttentionItems(factures, TODAY);
    const parCategorie = Object.fromEntries(items.map((i) => [i.category, i.count]));

    expect(parCategorie.en_retard).toBe(1);
    expect(parCategorie.refusees_litige).toBe(2);
    expect(parCategorie.artefacts_manquants).toBeGreaterThanOrEqual(1);
  });

  it("aucun élément si rien à signaler (liste vide -> tableau vide, jamais une catégorie à 0 affichée)", () => {
    expect(buildAttentionItems([], TODAY)).toEqual([]);
  });
});

describe("dashboardModel — buildRecentFactures", () => {
  it("trie par created_at décroissant, avec repli sur emise_at", () => {
    const factures = [
      facture({ id: "ancienne", created_at: "2026-08-01T10:00:00Z" }),
      facture({ id: "recente", created_at: "2026-08-20T10:00:00Z" }),
      facture({ id: "sans-created-at", created_at: null, emise_at: "2026-08-15T10:00:00Z" }),
    ];

    const recentes = buildRecentFactures(factures, 5);

    expect(recentes.map((f) => f.id)).toEqual(["recente", "sans-created-at", "ancienne"]);
  });

  it("respecte la limite demandée", () => {
    const factures = Array.from({ length: 10 }, () => facture());

    expect(buildRecentFactures(factures, 5)).toHaveLength(5);
  });
});
