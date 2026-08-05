import { render, screen } from "@testing-library/react";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { beforeEach, describe, expect, it, vi } from "vitest";
import userEvent from "@testing-library/user-event";
import * as devisApi from "../api/devisApi";
import * as evenementsDevisApi from "../api/evenementsDevisApi";
import type { Devis } from "../types/devis";
import { DevisDetailPage } from "./DevisDetailPage";

// Représentatif (§3 du prompt) : la visibilité du bouton "Convertir en
// facture" est dérivée UNIQUEMENT de statut === "accepte" ET !converti,
// tous deux fournis par l'API — jamais recalculés côté front. Zéro mock
// réseau réel : devisApi/evenementsDevisApi sont automockés par Vitest.
vi.mock("../api/devisApi");
vi.mock("../api/evenementsDevisApi");

function buildDevis(overrides: Partial<Devis>): Devis {
  return {
    id: "devis-1",
    client_id: "client-1",
    client: {
      id: "client-1",
      raison_sociale: "Client Test SAS",
      siret: "12345678900012",
      identifiant_routage_pa: null,
      email: "client@test.fr",
      ville: "Paris",
      pays: "FR",
      type: "entreprise",
    },
    numero: "DEV-2026-0001",
    objet: "Refonte du site",
    statut: "accepte",
    total_ht: "100.00",
    total_tva: "20.00",
    total_ttc: "120.00",
    conditions: null,
    date_emission: null,
    date_validite: "2026-09-01",
    expire: false,
    converti: false,
    facture_generee: null,
    lignes_devis: [],
    ...overrides,
  };
}

function renderDetailPage(devisId: string) {
  return render(
    <MemoryRouter initialEntries={[`/app/devis/${devisId}`]}>
      <Routes>
        <Route path="/app/devis/:id" element={<DevisDetailPage />} />
      </Routes>
    </MemoryRouter>,
  );
}

describe("DevisDetailPage — visibilité du bouton Convertir", () => {
  beforeEach(() => {
    vi.mocked(evenementsDevisApi.listEvenementsDevis).mockResolvedValue([]);
  });

  it("affiche « Convertir en facture » pour un devis accepté et non converti", async () => {
    vi.mocked(devisApi.getDevis).mockResolvedValue(
      buildDevis({ statut: "accepte", converti: false }),
    );

    renderDetailPage("devis-1");

    expect(
      await screen.findByRole("button", { name: "Convertir en facture" }),
    ).toBeInTheDocument();
  });

  it("cas négatif : masque le bouton Convertir dès que le devis est déjà converti", async () => {
    vi.mocked(devisApi.getDevis).mockResolvedValue(
      buildDevis({
        statut: "accepte",
        converti: true,
        facture_generee: { id: "facture-1", numero: "FAC-2026-0007" },
      }),
    );

    renderDetailPage("devis-1");

    await screen.findByText("Converti en facture FAC-2026-0007");

    expect(
      screen.queryByRole("button", { name: "Convertir en facture" }),
    ).not.toBeInTheDocument();
  });

  it("cas négatif : n'affiche pas le bouton Convertir tant que le devis n'est pas accepté", async () => {
    vi.mocked(devisApi.getDevis).mockResolvedValue(
      buildDevis({ statut: "envoye", converti: false }),
    );

    renderDetailPage("devis-1");

    await screen.findByRole("button", {
      name: "Enregistrer l’accord du client",
    });

    expect(
      screen.queryByRole("button", { name: "Convertir en facture" }),
    ).not.toBeInTheDocument();
  });
});

// §8 du palier V2-A : le panneau "accepté non converti" doit rester violet
// (statut par défaut, pas de modificateur --success) — le vert n'apparaît
// que sur la facture réellement générée.
describe("DevisDetailPage — sémantique violet/vert du panneau de décision (§8)", () => {
  beforeEach(() => {
    vi.mocked(evenementsDevisApi.listEvenementsDevis).mockResolvedValue([]);
  });

  it("accepté non converti : panneau violet par défaut, jamais l'état succès", async () => {
    vi.mocked(devisApi.getDevis).mockResolvedValue(
      buildDevis({ statut: "accepte", converti: false }),
    );

    renderDetailPage("devis-1");

    const intro = await screen.findByText("Accord enregistré");
    const panel = intro.closest(".devis-decision-panel");

    expect(panel).not.toBeNull();
    expect(panel).not.toHaveClass("devis-decision-panel--success");
    expect(screen.queryByText("Facture générée")).not.toBeInTheDocument();
  });

  it("refusé : aucune action primaire, jamais rouge", async () => {
    vi.mocked(devisApi.getDevis).mockResolvedValue(
      buildDevis({ statut: "refuse", converti: false }),
    );

    renderDetailPage("devis-1");

    await screen.findByText("Refus enregistré");

    expect(screen.queryAllByRole("button")).toHaveLength(0);
  });

  it("conversion en cours : l'action Convertir est désactivée, aucune redirection automatique", async () => {
    const user = userEvent.setup();

    vi.mocked(devisApi.getDevis).mockResolvedValue(
      buildDevis({ statut: "accepte", converti: false }),
    );
    vi.mocked(devisApi.convertirDevis).mockReturnValue(new Promise(() => {}));

    renderDetailPage("devis-1");

    await user.click(
      await screen.findByRole("button", { name: "Convertir en facture" }),
    );

    await user.click(
      await screen.findByRole("button", { name: "Créer la facture" }),
    );

    expect(
      await screen.findByRole("button", {
        name: "Création de la facture conforme…",
      }),
    ).toBeDisabled();

    expect(
      screen.getByRole("button", { name: "Conversion..." }),
    ).toBeDisabled();
  });
});
