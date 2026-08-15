import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";
import * as portailFactureTokensApi from "../api/portailFactureTokensApi";
import { InvoiceShareSection } from "./InvoiceShareSection";

vi.mock("../api/portailFactureTokensApi");

describe("InvoiceShareSection — portail destinataire (bouton owner)", () => {
  it("affiche le bouton Générer le lien de partage par défaut" , () => {
    render(<InvoiceShareSection factureId="facture-1" />);

    expect(
      screen.getByRole("button", { name: /Générer le lien de partage/ }),
    ).toBeInTheDocument();
  });

  it("au clic, génère le lien et l'affiche avec les actions copier/révoquer" , async () => {
    const user = userEvent.setup();
    vi.mocked(portailFactureTokensApi.genererLienPortail).mockResolvedValue(
      "http://localhost:5173/portail/abc123",
    );

    render(<InvoiceShareSection factureId="facture-1" />);

    await user.click(
      screen.getByRole("button", { name: /Générer le lien de partage/ }),
    );

    expect(
      await screen.findByText("http://localhost:5173/portail/abc123"),
    ).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: /Copier le lien/ }),
    ).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: /Révoquer le lien/ }),
    ).toBeInTheDocument();
    expect(
      screen.queryByRole("button", { name: /Générer le lien de partage/ }),
    ).not.toBeInTheDocument();
  });

  it("au clic sur Révoquer, retire le lien affiché et redonne le bouton Générer" , async () => {
    const user = userEvent.setup();
    vi.mocked(portailFactureTokensApi.genererLienPortail).mockResolvedValue(
      "http://localhost:5173/portail/abc123",
    );
    vi.mocked(portailFactureTokensApi.revoquerLienPortail).mockResolvedValue();

    render(<InvoiceShareSection factureId="facture-1" />);

    await user.click(
      screen.getByRole("button", { name: /Générer le lien de partage/ }),
    );
    await screen.findByText("http://localhost:5173/portail/abc123");

    await user.click(screen.getByRole("button", { name: /Révoquer le lien/ }));

    expect(portailFactureTokensApi.revoquerLienPortail).toHaveBeenCalledWith(
      "facture-1",
    );
    expect(
      await screen.findByRole("button", { name: /Générer le lien de partage/ }),
    ).toBeInTheDocument();
  });

  it("affiche l'erreur API sans faire planter la section" , async () => {
    const user = userEvent.setup();
    vi.mocked(portailFactureTokensApi.genererLienPortail).mockRejectedValue({
      response: { data: { error: "Accès refusé" } },
      isAxiosError: true,
    });

    render(<InvoiceShareSection factureId="facture-1" />);

    await user.click(
      screen.getByRole("button", { name: /Générer le lien de partage/ }),
    );

    expect(await screen.findByText("Accès refusé")).toBeInTheDocument();
  });
});
