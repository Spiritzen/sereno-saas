import { AlertTriangle } from "lucide-react";
import {
  useEffect,
  useRef,
  type KeyboardEvent,
  type MouseEvent,
} from "react";

type ConfirmModalProps = {
  open: boolean;
  title: string;
  message: string;
  confirmLabel: string;
  cancelLabel?: string;
  destructive?: boolean;
  isLoading?: boolean;
  onCancel: () => void;
  onConfirm: () => void;
};

export function ConfirmModal({
  open,
  title,
  message,
  confirmLabel,
  cancelLabel = "Annuler",
  destructive = false,
  isLoading = false,
  onCancel,
  onConfirm,
}: ConfirmModalProps) {
  const cancelButtonRef = useRef<HTMLButtonElement | null>(null);
  const confirmButtonRef = useRef<HTMLButtonElement | null>(null);

  useEffect(() => {
    if (!open) {
      return;
    }

    const timeoutId = window.setTimeout(() => {
      cancelButtonRef.current?.focus();
    }, 0);

    function handleDocumentKeyDown(event: globalThis.KeyboardEvent) {
      if (event.key !== "Escape") {
        return;
      }

      if (isLoading) {
        return;
      }

      onCancel();
    }

    document.addEventListener("keydown", handleDocumentKeyDown);

    return () => {
      window.clearTimeout(timeoutId);
      document.removeEventListener("keydown", handleDocumentKeyDown);
    };
  }, [open, isLoading, onCancel]);

  if (!open) {
    return null;
  }

  function getFocusableButtons() {
    const buttons: HTMLButtonElement[] = [];

    if (cancelButtonRef.current && !cancelButtonRef.current.disabled) {
      buttons.push(cancelButtonRef.current);
    }

    if (confirmButtonRef.current && !confirmButtonRef.current.disabled) {
      buttons.push(confirmButtonRef.current);
    }

    return buttons;
  }

  function handleDialogKeyDown(event: KeyboardEvent<HTMLDivElement>) {
    if (event.key !== "Tab") {
      return;
    }

    const focusableButtons = getFocusableButtons();
    const firstButton = focusableButtons[0];
    const lastButton = focusableButtons[focusableButtons.length - 1];

    if (!firstButton || !lastButton) {
      return;
    }

    if (event.shiftKey && document.activeElement === firstButton) {
      event.preventDefault();
      lastButton.focus();
      return;
    }

    if (!event.shiftKey && document.activeElement === lastButton) {
      event.preventDefault();
      firstButton.focus();
    }
  }

  function handleBackdropMouseDown(event: MouseEvent<HTMLDivElement>) {
    if (event.target !== event.currentTarget) {
      return;
    }

    if (isLoading) {
      return;
    }

    onCancel();
  }

  return (
    <div
      className="client-modal-backdrop"
      role="presentation"
      onMouseDown={handleBackdropMouseDown}
    >
      <div
        className="confirmation-modal"
        role="dialog"
        aria-modal="true"
        aria-labelledby="confirm-modal-title"
        aria-describedby="confirm-modal-description"
        onKeyDown={handleDialogKeyDown}
      >
        <div className={`confirmation-icon ${destructive ? "danger" : ""}`}>
          <AlertTriangle size={22} />
        </div>

        <div>
          <span className="page-kicker">
            {destructive ? "Action définitive" : "Confirmation"}
          </span>

          <h2 id="confirm-modal-title">{title}</h2>

          <p id="confirm-modal-description">{message}</p>
        </div>

        <div className="confirmation-actions">
          <button
            ref={cancelButtonRef}
            type="button"
            className="secondary-btn"
            disabled={isLoading}
            onClick={onCancel}
          >
            {cancelLabel}
          </button>

          <button
            ref={confirmButtonRef}
            type="button"
            className={destructive ? "danger-btn" : "primary-btn"}
            disabled={isLoading}
            onClick={onConfirm}
          >
            {confirmLabel}
          </button>
        </div>
      </div>
    </div>
  );
}