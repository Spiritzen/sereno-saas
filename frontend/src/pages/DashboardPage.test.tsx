import { render, screen, waitFor, within } from "@testing-library/react";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import * as authApi from "../api/authApi";
import * as clientsApi from "../api/clientsApi";
import * as facturesApi from "../api/facturesApi";
import { AuthProvider } from "../context/AuthProvider";
import type { Facture, FactureStatut } from "../types/facture";
import { DashboardPage } from "./DashboardPage";

// D1 (§9, tests obligatoires) — zéro mock réseau réel : authApi/facturesApi/
// clientsApi sont automockés par Vitest, comme pour AppShell.test.tsx.
vi.mock("../api/authApi");
vi.mock("../api/facturesApi");
vi.mock("../api/clientsApi");

let sequence = 0;

function buildFacture(overrides: Partial<Facture> = {}): Facture {
  sequence += 1;

  return {
    id: `fac-${sequence}`,
    client_id: `cli-${sequence}`,
    client: { id: `cli-${sequence}`, raison_sociale: `Client ${sequence}`, siret: "12345678900012", identifiant_routage_pa: null, email: "c@test.fr", ville: "Paris", pays: "FR", type: "entreprise" },
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
    pdf_url: "/storage/facture.pdf",
    xml_url: "/storage/facture.xml",
    emise_at: "2026-08-01T10:00:00Z",
    created_at: "2026-08-01T10:00:00Z",
    ...overrides,
  };
}

function mockAuth() {
  window.localStorage.setItem("sereno.session.active", "true");
  vi.mocked(authApi.me).mockResolvedValue({
    utilisateur: {
      id: "u1",
      email: "sebastien@test.fr",
      nom: "Cantrelle",
      prenom: "Sébastien",
      role: "owner",
      actif: true,
    },
    organisation: {
      id: "o1",
      raison_sociale: "Studio Démo",
      siret: "12345678900000",
      regime_tva: "reel",
    },
  });
}

function renderDashboard() {
  return render(
    <MemoryRouter initialEntries={["/app/dashboard"]}>
      <AuthProvider>
        <Routes>
          <Route path="/app/dashboard" element={<DashboardPage />} />
          <Route path="/app/factures" element={<div>Page factures</div>} />
          <Route path="/app/factures/new" element={<div>Nouvelle facture</div>} />
          <Route path="/app/factures/:id" element={<div>Détail facture</div>} />
          <Route path="/app/devis/new" element={<div>Nouveau devis</div>} />
          <Route path="/app/clients" element={<div>Page clients</div>} />
          <Route path="/app/parametres" element={<div>Page paramètres</div>} />
        </Routes>
      </AuthProvider>
    </MemoryRouter>,
  );
}

afterEach(() => {
  window.localStorage.clear();
  vi.useRealTimers();
});

describe("DashboardPage — chargement et prénom réel", () => {
  beforeEach(() => {
    mockAuth();
  });

  it("affiche un état de chargement puis les données réelles", async () => {
    vi.mocked(facturesApi.listFactures).mockResolvedValue([buildFacture()]);
    vi.mocked(clientsApi.listClients).mockResolvedValue([]);

    renderDashboard();

    expect(screen.getByText(/Chargement des factures/i)).toBeInTheDocument();

    await waitFor(() => {
      expect(screen.queryByText(/Chargement des factures/i)).not.toBeInTheDocument();
    });
  });

  it("affiche le prénom réel de l'utilisateur authentifié dans la salutation", async () => {
    vi.mocked(facturesApi.listFactures).mockResolvedValue([]);
    vi.mocked(clientsApi.listClients).mockResolvedValue([]);

    renderDashboard();

    await waitFor(() => {
      expect(screen.getByRole("heading", { level: 1 })).toHaveTextContent("Bonjour Sébastien");
    });
  });

  it("affiche une erreur API sans faire planter la page", async () => {
    vi.mocked(facturesApi.listFactures).mockRejectedValue(new Error("Serveur indisponible"));
    vi.mocked(clientsApi.listClients).mockResolvedValue([]);

    renderDashboard();

    await waitFor(() => {
      expect(screen.getByText("Serveur indisponible")).toBeInTheDocument();
    });
  });

  it("affiche un état vide honnête quand il n'y a aucune facture", async () => {
    vi.mocked(facturesApi.listFactures).mockResolvedValue([]);
    vi.mocked(clientsApi.listClients).mockResolvedValue([]);

    renderDashboard();

    await waitFor(() => {
      expect(screen.getByText("Aucune facture pour le moment.")).toBeInTheDocument();
    });

    // Complétude honnête : jamais 100% quand aucune facture n'est émise.
    expect(screen.getByText("Aucun document émis")).toBeInTheDocument();
    expect(screen.getByText("—")).toBeInTheDocument();
  });
});

describe("DashboardPage — 4 KPI honnêtes et absence de données fictives", () => {
  beforeEach(() => {
    mockAuth();
  });

  it("affiche les 4 KPI avec des libellés honnêtes, jamais 'Encaissé · réel' ni 'Conformité'", async () => {
    vi.mocked(facturesApi.listFactures).mockResolvedValue([
      buildFacture({ statut: "encaissee" }),
      buildFacture({ statut: "emise", date_echeance: "2099-01-01" }),
    ]);
    vi.mocked(clientsApi.listClients).mockResolvedValue([]);

    renderDashboard();

    await waitFor(() => {
      expect(screen.getByText("Encaissement constaté")).toBeInTheDocument();
    });

    expect(screen.getByText("En attente")).toBeInTheDocument();
    expect(screen.getByText("En retard")).toBeInTheDocument();
    expect(screen.getByText("Complétude")).toBeInTheDocument();

    expect(screen.queryByText(/Encaissé · réel/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/^Conformité$/i)).not.toBeInTheDocument();
  });

  it("ne mentionne jamais de données fictives (PA connectée, Plan Premium, notifications, activité récente)", async () => {
    vi.mocked(facturesApi.listFactures).mockResolvedValue([buildFacture()]);
    vi.mocked(clientsApi.listClients).mockResolvedValue([]);

    renderDashboard();

    await waitFor(() => {
      expect(screen.getByText("Factures récentes")).toBeInTheDocument();
    });

    expect(screen.queryByText(/PA connectée/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/réception active/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/Plan Premium/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/Activité récente/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/il y a \d+ heure/i)).not.toBeInTheDocument();
  });

  it("représente une facture en retard sans dépendre uniquement de la couleur (texte 'En retard' explicite)", async () => {
    vi.setSystemTime(new Date("2026-08-20T10:00:00"));

    vi.mocked(facturesApi.listFactures).mockResolvedValue([
      buildFacture({ statut: "emise", date_echeance: "2026-08-01" }),
    ]);
    vi.mocked(clientsApi.listClients).mockResolvedValue([]);

    renderDashboard();

    await waitFor(() => {
      expect(screen.getAllByText("En retard").length).toBeGreaterThan(0);
    });
  });
});

describe("DashboardPage — liens réels et limites d'affichage", () => {
  beforeEach(() => {
    mockAuth();
  });

  it("le CTA principal et les actions rapides pointent vers des routes réelles", async () => {
    vi.mocked(facturesApi.listFactures).mockResolvedValue([]);
    vi.mocked(clientsApi.listClients).mockResolvedValue([]);

    renderDashboard();

    await waitFor(() => {
      expect(screen.getByRole("link", { name: /Nouvelle facture conforme/i })).toBeInTheDocument();
    });

    expect(screen.getByRole("link", { name: /Nouvelle facture conforme/i })).toHaveAttribute(
      "href",
      "/app/factures/new",
    );

    const quickActions = screen.getByRole("navigation", { name: "Actions rapides" });
    expect(within(quickActions).getByRole("link", { name: /Nouveau devis/i })).toHaveAttribute(
      "href",
      "/app/devis/new",
    );
    expect(within(quickActions).getByRole("link", { name: /Clients/i })).toHaveAttribute(
      "href",
      "/app/clients",
    );
    expect(within(quickActions).getByRole("link", { name: /Paramètres/i })).toHaveAttribute(
      "href",
      "/app/parametres",
    );
  });

  it("chaque ligne de facture récente pointe vers /app/factures/:id", async () => {
    const facture = buildFacture({
      id: "fac-cible",
      client: {
        id: "cli-cible",
        raison_sociale: "Client Cible SAS",
        siret: "12345678900012",
        identifiant_routage_pa: null,
        email: "cible@test.fr",
        ville: "Paris",
        pays: "FR",
        type: "entreprise",
      },
    });
    vi.mocked(facturesApi.listFactures).mockResolvedValue([facture]);
    vi.mocked(clientsApi.listClients).mockResolvedValue([]);

    renderDashboard();

    await waitFor(() => {
      expect(screen.getByText("Factures récentes")).toBeInTheDocument();
    });

    const invoicesCard = screen.getByText("Factures récentes").closest("section") as HTMLElement;
    const row = within(invoicesCard).getByText("Client Cible SAS").closest("a");
    expect(row).toHaveAttribute("href", "/app/factures/fac-cible");
  });

  it("n'affiche jamais plus de 5 factures récentes", async () => {
    const factures = Array.from({ length: 12 }, (_, i) =>
      buildFacture({ created_at: `2026-08-${String(20 - i).padStart(2, "0")}T10:00:00Z` }),
    );
    vi.mocked(facturesApi.listFactures).mockResolvedValue(factures);
    vi.mocked(clientsApi.listClients).mockResolvedValue([]);

    renderDashboard();

    await waitFor(() => {
      expect(screen.getByText("Factures récentes")).toBeInTheDocument();
    });

    const invoicesCard = screen.getByText("Factures récentes").closest("section");
    const rows = within(invoicesCard as HTMLElement).getAllByRole("link", { name: /Client/i });
    expect(rows.length).toBeLessThanOrEqual(5);
  });

  it("n'affiche jamais plus de 3 échéances dans le right rail", async () => {
    const factures = Array.from({ length: 8 }, (_, i) =>
      buildFacture({ statut: "emise", date_echeance: `2026-09-${String(1 + i).padStart(2, "0")}` }),
    );
    vi.mocked(facturesApi.listFactures).mockResolvedValue(factures);
    vi.mocked(clientsApi.listClients).mockResolvedValue([]);

    renderDashboard();

    await waitFor(() => {
      expect(screen.getByText("Échéances à venir")).toBeInTheDocument();
    });

    const deadlinesPanel = screen.getByText("Échéances à venir").closest("section");
    const items = within(deadlinesPanel as HTMLElement).getAllByRole("listitem");
    expect(items.length).toBeLessThanOrEqual(3);
  });
});

// D1.1 (prompt_claude_code_dashboard_d1_1_regulation_grille_etats_reseau.txt
// §8) — la machine d'état réseau doit distinguer LOADING / ERROR / READY :
// aucune des deux premières ne doit jamais se présenter comme un résultat
// métier ("0 €", "100 %", "Aucune échéance à suivre pour le moment", "Rien
// d'urgent pour le moment").
const FAUX_ETATS_RASSURANTS = [
  /^0\s€$/,
  /100\s?%/,
  "Aucune échéance à suivre pour le moment.",
  "Rien d'urgent pour le moment.",
];

function expectNoFauxEtatRassurant() {
  for (const pattern of FAUX_ETATS_RASSURANTS) {
    expect(screen.queryByText(pattern)).not.toBeInTheDocument();
  }
}

describe("DashboardPage — D1.1 machine d'état réseau honnête", () => {
  beforeEach(() => {
    mockAuth();
  });

  it("T-D1.1-LOADING-HONNETE — affiche un état de chargement, jamais un résultat métier", async () => {
    // Promesse volontairement jamais résolue : la page reste en LOADING.
    vi.mocked(facturesApi.listFactures).mockReturnValue(new Promise(() => {}));
    vi.mocked(clientsApi.listClients).mockResolvedValue([]);

    renderDashboard();

    expect(await screen.findByText("Chargement des factures...")).toBeInTheDocument();
    expectNoFauxEtatRassurant();

    // La région de données est bien signalée occupée pour les lecteurs d'écran.
    expect(document.querySelector('[aria-busy="true"]')).not.toBeNull();
  });

  it("T-D1.1-ERROR-HONNETE — affiche une erreur accessible, jamais un portefeuille vide déguisé", async () => {
    vi.mocked(facturesApi.listFactures).mockRejectedValue(new Error("Panne réseau simulée"));
    vi.mocked(clientsApi.listClients).mockResolvedValue([]);

    renderDashboard();

    const alert = await screen.findByRole("alert");
    expect(alert).toHaveTextContent("Panne réseau simulée");

    expectNoFauxEtatRassurant();

    // Un seul message d'erreur principal (role="alert") : les autres
    // panneaux affichent un texte neutre, jamais quatre alertes identiques.
    expect(screen.getAllByRole("alert")).toHaveLength(1);
    expect(screen.getAllByText("Données indisponibles").length).toBeGreaterThanOrEqual(1);
  });

  it("T-D1.1-EMPTY-REEL — une réponse réussie et réellement vide devient un vrai état vide", async () => {
    vi.mocked(facturesApi.listFactures).mockResolvedValue([]);
    vi.mocked(clientsApi.listClients).mockResolvedValue([]);

    renderDashboard();

    await screen.findByText("Aucune facture pour le moment.");

    expect(screen.getByText("Aucune échéance à suivre pour le moment.")).toBeInTheDocument();
    expect(screen.getByText("Rien d'urgent pour le moment.")).toBeInTheDocument();

    // Complétude reste "—" (aucun document émis), jamais 100 % par défaut.
    expect(screen.getByText("Aucun document émis")).toBeInTheDocument();

    // Les 3 KPI de somme peuvent honnêtement afficher 0 € à l'état ready+vide
    // (Encaissement constaté, En attente, En retard) — distinct de "—".
    expect(screen.getAllByText(/^0\s€$/)).toHaveLength(3);

    expect(document.querySelector('[aria-busy="true"]')).toBeNull();
  });

  it("T-D1.1-DATA-PRESERVEE — les 4 règles KPI D1 restent inchangées après le refactor réseau", async () => {
    vi.mocked(facturesApi.listFactures).mockResolvedValue([
      buildFacture({ statut: "encaissee", total_ttc: "500.00" }),
      buildFacture({ statut: "emise", date_echeance: "2099-01-01", total_ttc: "300.00" }),
      buildFacture({ statut: "deposee", date_echeance: "2020-01-01", total_ttc: "150.00" }),
    ]);
    vi.mocked(clientsApi.listClients).mockResolvedValue([]);

    renderDashboard();

    await screen.findByText("Factures récentes");

    const kpiGrid = screen.getByRole("region", { name: "Indicateurs de facturation" });
    expect(within(kpiGrid).getByText(/^500\s€$/)).toBeInTheDocument(); // encaissement constaté
    expect(within(kpiGrid).getByText(/^300\s€$/)).toBeInTheDocument(); // en attente (hors retard)
    expect(within(kpiGrid).getByText(/^150\s€$/)).toBeInTheDocument(); // en retard

    // Complétude : les 3 factures sont non-brouillon et toutes pdf+xml
    // complètes par défaut dans la fixture => 100 %.
    expect(within(kpiGrid).getByText("100%")).toBeInTheDocument();
  });

  it("T-D1.1-STRUCTURE — PreflightBanner/KPI/Factures en colonne principale, Échéances/À traiter en right rail, actions rapides après la grille", async () => {
    vi.mocked(facturesApi.listFactures).mockResolvedValue([]);
    vi.mocked(clientsApi.listClients).mockResolvedValue([]);

    const { container } = renderDashboard();

    await screen.findByText("Aucune facture pour le moment.");

    const mainColumn = container.querySelector(".dashboard-main-column");
    const rightRail = container.querySelector(".dashboard-right-rail");
    const cockpitGrid = container.querySelector(".dashboard-cockpit-grid");
    expect(mainColumn).not.toBeNull();
    expect(rightRail).not.toBeNull();
    expect(cockpitGrid).not.toBeNull();

    expect(mainColumn?.querySelector('section[aria-label="Pré-contrôles actifs"]')).not.toBeNull();
    expect(mainColumn?.querySelector('section[aria-label="Indicateurs de facturation"]')).not.toBeNull();
    expect(mainColumn?.querySelector(".dashboard-invoices-card")).not.toBeNull();

    expect(rightRail?.querySelector('section[aria-label="Échéances réelles"]')).not.toBeNull();
    expect(rightRail?.querySelector('section[aria-label="À traiter"]')).not.toBeNull();

    // Les échéances/à traiter ne doivent pas être dans la colonne principale,
    // ni le bandeau/KPI/factures dans le right rail.
    expect(mainColumn?.querySelector('section[aria-label="Échéances réelles"]')).toBeNull();
    expect(rightRail?.querySelector('section[aria-label="Pré-contrôles actifs"]')).toBeNull();

    // La barre d'actions rapides suit la zone à 2 colonnes, jamais dedans.
    const quickActions = container.querySelector('nav[aria-label="Actions rapides"]');
    expect(quickActions).not.toBeNull();
    expect(cockpitGrid?.contains(quickActions as Node)).toBe(false);
  });
});
