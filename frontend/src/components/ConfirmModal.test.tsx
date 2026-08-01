import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";
import { ConfirmModal } from "./ConfirmModal";

describe("ConfirmModal", () => {
  it("appelle onConfirm au clic sur le bouton de confirmation", async () => {
    const user = userEvent.setup();
    const onConfirm = vi.fn();
    const onCancel = vi.fn();

    render(
      <ConfirmModal
        open
        title="Annuler ce paiement ?"
        message="Le reste à payer sera recalculé."
        confirmLabel="Confirmer"
        onCancel={onCancel}
        onConfirm={onConfirm}
      />,
    );

    await user.click(screen.getByRole("button", { name: "Confirmer" }));

    expect(onConfirm).toHaveBeenCalledTimes(1);
    expect(onCancel).not.toHaveBeenCalled();
  });

  it("appelle onCancel au clic sur le bouton d'annulation", async () => {
    const user = userEvent.setup();
    const onConfirm = vi.fn();
    const onCancel = vi.fn();

    render(
      <ConfirmModal
        open
        title="Annuler ce paiement ?"
        message="Le reste à payer sera recalculé."
        confirmLabel="Confirmer"
        onCancel={onCancel}
        onConfirm={onConfirm}
      />,
    );

    await user.click(screen.getByRole("button", { name: "Annuler" }));

    expect(onCancel).toHaveBeenCalledTimes(1);
    expect(onConfirm).not.toHaveBeenCalled();
  });

  it("désactive les boutons et n'appelle pas onConfirm quand isLoading (cas négatif)", async () => {
    const user = userEvent.setup();
    const onConfirm = vi.fn();
    const onCancel = vi.fn();

    render(
      <ConfirmModal
        open
        isLoading
        title="Annuler ce paiement ?"
        message="Le reste à payer sera recalculé."
        confirmLabel="Confirmer"
        onCancel={onCancel}
        onConfirm={onConfirm}
      />,
    );

    const confirmButton = screen.getByRole("button", { name: "Confirmer" });
    const cancelButton = screen.getByRole("button", { name: "Annuler" });

    expect(confirmButton).toBeDisabled();
    expect(cancelButton).toBeDisabled();

    await user.click(confirmButton);

    expect(onConfirm).not.toHaveBeenCalled();
  });

  it("applique la classe destructive sur le bouton de confirmation", () => {
    render(
      <ConfirmModal
        open
        destructive
        title="Supprimer ?"
        message="Action définitive."
        confirmLabel="Supprimer"
        onCancel={vi.fn()}
        onConfirm={vi.fn()}
      />,
    );

    expect(screen.getByRole("button", { name: "Supprimer" }).className).toContain(
      "danger-btn",
    );
  });
});
