import { AlertTriangle } from "lucide-react";
import { useRef } from "react";
import { ModalShell } from "./ModalShell";

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

  return (
    <ModalShell
      open={open}
      onClose={onCancel}
      labelledBy="confirm-modal-title"
      describedBy="confirm-modal-description"
      isDismissDisabled={isLoading}
      initialFocusRef={cancelButtonRef}
      surfaceClassName="confirmation-modal"
    >
      <div className="modal-shell__header">
        <div className={`confirmation-icon ${destructive ? "danger" : ""}`}>
          <AlertTriangle size={22} />
        </div>

        <div>
          <span className="page-kicker">
            {destructive ? "Action définitive" : "Confirmation"}
          </span>

          <h2 id="confirm-modal-title">{title}</h2>
        </div>
      </div>

      <div className="modal-shell__body">
        <p id="confirm-modal-description">{message}</p>
      </div>

      <footer className="modal-shell__footer confirmation-actions">
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
          type="button"
          className={destructive ? "danger-btn" : "primary-btn"}
          disabled={isLoading}
          onClick={onConfirm}
        >
          {confirmLabel}
        </button>
      </footer>
    </ModalShell>
  );
}
