import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { beforeEach, describe, expect, it, vi } from "vitest";
import * as destinataireApi from "../api/destinataireApi";
import { DestinataireAuthProvider } from "../context/DestinataireAuthProvider";
import { EspaceClientActivationPage } from "./EspaceClientActivationPage";

vi.mock("../api/destinataireApi");

function renderPage(token = "abc123brut") {
  return render(
    <MemoryRouter initialEntries={[`/espace-client/activer/${token}`]}>
      <DestinataireAuthProvider>
        <Routes>
          <Route path="/espace-client/activer/:token" element={<EspaceClientActivationPage />} />
          <Route path="/espace-client" element={<div>Placeholder accueil</div>} />
          <Route path="/espace-client/connexion" element={<div>Page connexion</div>} />
        </Routes>
      </DestinataireAuthProvider>
    </MemoryRouter>,
  );
}

async function remplirEtSoumettre(user: ReturnType<typeof userEvent.setup>, {
  email = "nouveau@test.fr",
  motDePasse = "motdepasse123",
  confirmation = motDePasse,
} = {}) {
  await user.type(screen.getByPlaceholderText("Votre email"), email);
  await user.type(screen.getByPlaceholderText("Choisissez un mot de passe"), motDePasse);
  await user.type(screen.getByPlaceholderText("Confirmez le mot de passe"), confirmation);
  await user.click(screen.getByRole("button", { name: "Créer mon espace" }));
}

describe("EspaceClientActivationPage", () => {
  beforeEach(() => {
    window.localStorage.clear();
    vi.clearAllMocks();
  });

  it("passe le token de l'URL au POST — succès -> connecté (placeholder)", async () => {
    const user = userEvent.setup();
    vi.mocked(destinataireApi.inscription).mockResolvedValue({ email: "nouveau@test.fr", fournisseurs_lies: 1 });

    renderPage("mon-token-brut");
    await remplirEtSoumettre(user);

    expect(await screen.findByText("Placeholder accueil")).toBeInTheDocument();
    expect(destinataireApi.inscription).toHaveBeenCalledWith({
      token: "mon-token-brut",
      email: "nouveau@test.fr",
      mot_de_passe: "motdepasse123",
    });
  });

  it("mots de passe différents -> erreur cliente, AUCUN appel API", async () => {
    const user = userEvent.setup();

    renderPage();
    await remplirEtSoumettre(user, { confirmation: "autre-mot-de-passe" });

    expect(
      await screen.findByText("Les deux mots de passe ne correspondent pas."),
    ).toBeInTheDocument();
    expect(destinataireApi.inscription).not.toHaveBeenCalled();
  });

  it("mot de passe trop court -> erreur cliente, AUCUN appel API", async () => {
    const user = userEvent.setup();

    renderPage();
    await remplirEtSoumettre(user, { motDePasse: "court", confirmation: "court" });

    expect(await screen.findByText(/au moins 8 caractères/)).toBeInTheDocument();
    expect(destinataireApi.inscription).not.toHaveBeenCalled();
  });

  it("lien invalide/expiré -> message sobre, distinct de l'erreur brute backend", async () => {
    const user = userEvent.setup();
    vi.mocked(destinataireApi.inscription).mockRejectedValue({
      response: { data: { error: "Lien invalide ou expiré" } },
      isAxiosError: true,
    });

    renderPage();
    await remplirEtSoumettre(user);

    expect(await screen.findByText("Ce lien n'est plus valide.")).toBeInTheDocument();
  });

  it("e-mail déjà pris -> message + lien vers connexion", async () => {
    const user = userEvent.setup();
    vi.mocked(destinataireApi.inscription).mockRejectedValue({
      response: { data: { error: "Un compte existe déjà avec cet e-mail — connectez-vous." } },
      isAxiosError: true,
    });

    renderPage();
    await remplirEtSoumettre(user, { email: "existe@test.fr" });

    expect(await screen.findByText(/Un compte existe déjà/)).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Connectez-vous" })).toHaveAttribute(
      "href",
      "/espace-client/connexion",
    );
  });
});
