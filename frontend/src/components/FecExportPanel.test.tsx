import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";
import * as exportsApi from "../api/exportsApi";
import { FecExportPanel } from "./FecExportPanel";

vi.mock("../api/exportsApi");

describe("FecExportPanel — export comptable (FEC MVP)", () => {
  it("affiche l'étiquette d'honnêteté dès que l'aperçu est chargé" , async () => {
    vi.mocked(exportsApi.getFecApercu).mockResolvedValue({
      etiquette:
        "FEC reconstitué automatiquement à partir des factures, avoirs et paiements de Sereno — ce n'est pas une comptabilité tenue.",
      nom_fichier: "123456789FEC20261231.txt",
    });

    render(<FecExportPanel />);

    expect(
      await screen.findByText(/ce n'est pas une comptabilité tenue/),
    ).toBeInTheDocument();
  });

  it("désactive le téléchargement tant que l'étiquette n'est pas chargée" , () => {
    vi.mocked(exportsApi.getFecApercu).mockReturnValue(new Promise(() => {}));

    render(<FecExportPanel />);

    expect(screen.getByRole("button")).toBeDisabled();
  });

  it("le téléchargement ouvre l'URL construite depuis la plage de dates affichée" , async () => {
    const user = userEvent.setup();
    vi.mocked(exportsApi.getFecApercu).mockResolvedValue({
      etiquette: "FEC reconstitué automatiquement...",
      nom_fichier: "123456789FEC20261231.txt",
    });
    vi.mocked(exportsApi.getFecExportUrl).mockReturnValue(
      "http://localhost:3000/api/v1/exports/fec?debut=2026-01-01&fin=2026-12-31",
    );
    const openSpy = vi.spyOn(window, "open").mockImplementation(() => null);

    render(<FecExportPanel />);

    const bouton = await screen.findByRole("button", { name: /Télécharger le FEC/ });
    expect(bouton).toBeEnabled();

    await user.click(bouton);

    await waitFor(() => expect(openSpy).toHaveBeenCalled());
    expect(openSpy.mock.calls[0][0]).toContain("/exports/fec?");

    openSpy.mockRestore();
  });

  it("affiche une erreur sobre si l'aperçu échoue, sans planter le panneau" , async () => {
    vi.mocked(exportsApi.getFecApercu).mockRejectedValue({
      response: { data: { error: "Accès refusé" } },
      isAxiosError: true,
    });

    render(<FecExportPanel />);

    expect(await screen.findByText("Accès refusé")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /Télécharger le FEC/ })).toBeDisabled();
  });
});
