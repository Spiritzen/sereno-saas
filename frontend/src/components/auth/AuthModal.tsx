import { ShieldCheck } from "lucide-react";
import { useNavigate } from "react-router-dom";
import { ModalShell } from "../ModalShell";
import { LoginForm } from "./LoginForm";

type AuthModalProps = {
  open: boolean;
  onClose: () => void;
};

// R3 (§10) — connexion en modale ACCESSIBLE, réutilisant ModalShell TEL QUEL
// (portail, piège de focus, Échap, restauration du focus, verrou de scroll —
// déjà construits et déjà éprouvés par ConfirmModal/MobileNavDrawer) : aucune
// mécanique de modale réinventée ici. ModalShell place déjà le focus sur le
// premier élément focusable de la surface (ici le champ e-mail de
// LoginForm) — aucune ref de focus initial supplémentaire n'est nécessaire.
// Le formulaire est le MÊME composant que /login (LoginForm) — une seule
// logique de soumission/erreur.
export function AuthModal({ open, onClose }: AuthModalProps) {
  const navigate = useNavigate();

  function handleSuccess() {
    onClose();
    navigate("/app/dashboard");
  }

  return (
    <ModalShell
      open={open}
      onClose={onClose}
      labelledBy="auth-modal-title"
      surfaceClassName="auth-modal"
    >
      <div className="modal-shell__header">
        <div className="login-brand">
          <div className="brand-mark">S</div>
          <div>
            <strong>Sereno</strong>
            <span>Facturation électronique conforme</span>
          </div>
        </div>

        <div className="login-copy">
          <span className="pa-pill">
            <ShieldCheck size={14} /> Espace sécurisé
          </span>

          <h2 id="auth-modal-title">Connexion</h2>
          <p>Accédez à votre cockpit conformité en un instant.</p>
        </div>
      </div>

      <div className="modal-shell__body">
        <LoginForm onSuccess={handleSuccess} />
      </div>
    </ModalShell>
  );
}
