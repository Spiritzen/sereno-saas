import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter } from "react-router-dom";
import { beforeEach, describe, expect, it, vi } from "vitest";
import * as authApi from "../../api/authApi";
import { AuthProvider } from "../../context/AuthProvider";
import { Sidebar } from "./Sidebar";

vi.mock("../../api/authApi");

function renderSidebar(props: { forceExpanded?: boolean } = {}) {
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

  return render(
    <MemoryRouter initialEntries={["/app/dashboard"]}>
      <AuthProvider>
        <Sidebar {...props} />
      </AuthProvider>
    </MemoryRouter>,
  );
}

describe("Sidebar", () => {
  beforeEach(() => {
    window.localStorage.clear();
    vi.clearAllMocks();
  });

  it("D0 §2 — déployée par défaut (libellés visibles), logo + marque en tête", async () => {
    renderSidebar();

    expect(await screen.findByText("Sereno")).toBeInTheDocument();
    expect(screen.getByText("Studio Démo")).toBeInTheDocument();
    expect(screen.getByRole("img", { name: "Sereno" })).toBeInTheDocument();
    expect(screen.getByText("Dashboard")).toBeInTheDocument();
    expect(screen.getByText("Factures")).toBeInTheDocument();
  });

  it("le chevron réduit puis redéploie la sidebar (classe .expanded + libellés conditionnés en JSX)", async () => {
    const user = userEvent.setup();
    renderSidebar();

    await screen.findByText("Dashboard");
    // .nav-label est masqué par CSS (display:none par défaut), jamais testable
    // ici (vitest tourne avec `css: false`, cf. vite.config.ts) — on vérifie
    // à la place ce qui est réellement conditionné en JSX (Sidebar.tsx) :
    // la classe .expanded et le texte "Sereno"/"Réduire", rendus seulement
    // si isExpanded.
    const aside = screen.getByText("Dashboard").closest("aside") as HTMLElement;
    expect(aside).toHaveClass("expanded");
    expect(screen.getByText("Sereno")).toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "Réduire le menu" }));
    expect(aside).not.toHaveClass("expanded");
    expect(screen.queryByText("Sereno")).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Développer le menu" })).toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "Développer le menu" }));
    expect(aside).toHaveClass("expanded");
    expect(screen.getByText("Sereno")).toBeInTheDocument();
  });

  it("n'invente AUCUNE entrée : uniquement les routes réelles existantes", async () => {
    renderSidebar();

    await screen.findByText("Dashboard");

    expect(screen.queryByText("Avoirs")).not.toBeInTheDocument();
    expect(screen.queryByText("Paiements")).not.toBeInTheDocument();
    expect(screen.queryByText(/Produits/)).not.toBeInTheDocument();
  });

  it("bloc profil réel en pied de sidebar (nom, rôle), PAS de bloc abonnement", async () => {
    renderSidebar();

    expect(await screen.findByText("Sébastien Cantrelle")).toBeInTheDocument();
    expect(screen.getByText("Owner")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Se déconnecter" })).toBeInTheDocument();
    expect(screen.queryByText(/Plan/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/Premium/i)).not.toBeInTheDocument();
  });

  it("forceExpanded (drawer mobile) : toujours déployée, chevron masqué", async () => {
    renderSidebar({ forceExpanded: true });

    expect(await screen.findByText("Dashboard")).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Réduire le menu" })).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Développer le menu" })).not.toBeInTheDocument();
  });
});
