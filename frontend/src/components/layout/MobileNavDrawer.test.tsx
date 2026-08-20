import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";
import { MobileNavDrawer } from "./MobileNavDrawer";

describe("MobileNavDrawer", () => {
  it("fermé -> ne rend rien", () => {
    render(
      <MobileNavDrawer isOpen={false} onClose={vi.fn()} label="Navigation" id="test-drawer">
        <div>Contenu nav</div>
      </MobileNavDrawer>,
    );

    expect(screen.queryByText("Contenu nav")).not.toBeInTheDocument();
  });

  it("ouvert -> affiche le contenu repris tel quel (dialog accessible)", () => {
    render(
      <MobileNavDrawer isOpen onClose={vi.fn()} label="Navigation" id="test-drawer">
        <div>Contenu nav</div>
      </MobileNavDrawer>,
    );

    expect(screen.getByText("Contenu nav")).toBeInTheDocument();
    expect(screen.getByRole("dialog", { name: "Navigation" })).toBeInTheDocument();
  });

  it("clic sur le bouton de fermeture -> onClose", async () => {
    const user = userEvent.setup();
    const onClose = vi.fn();

    render(
      <MobileNavDrawer isOpen onClose={onClose} label="Navigation" id="test-drawer">
        <div>Contenu nav</div>
      </MobileNavDrawer>,
    );

    await user.click(screen.getByRole("button", { name: "Fermer le menu" }));

    expect(onClose).toHaveBeenCalledTimes(1);
  });

  it("clic sur le fond -> onClose (ModalShell)", async () => {
    const user = userEvent.setup();
    const onClose = vi.fn();

    render(
      <MobileNavDrawer isOpen onClose={onClose} label="Navigation" id="test-drawer">
        <div>Contenu nav</div>
      </MobileNavDrawer>,
    );

    await user.click(screen.getByRole("presentation"));

    expect(onClose).toHaveBeenCalledTimes(1);
  });

  it("touche Échap -> onClose (ModalShell)", async () => {
    const user = userEvent.setup();
    const onClose = vi.fn();

    render(
      <MobileNavDrawer isOpen onClose={onClose} label="Navigation" id="test-drawer">
        <div>Contenu nav</div>
      </MobileNavDrawer>,
    );

    await user.keyboard("{Escape}");

    expect(onClose).toHaveBeenCalledTimes(1);
  });
});
