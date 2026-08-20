import { X } from "lucide-react";
import type { ReactNode } from "react";
import { ModalShell } from "../ModalShell";

type MobileNavDrawerProps = {
  isOpen: boolean;
  onClose: () => void;
  label: string;
  children: ReactNode;
  // §6.5 prompt de reprise — le bouton hamburger déclencheur a besoin d'un
  // aria-controls pointant vers un id RÉEL du tiroir. ModalShell (composant
  // partagé, hors périmètre autorisé de ce sprint) ne pose pas d'id sur sa
  // surface : on pointe donc vers le titre accessible du tiroir (dérivé de
  // cet id), présent dans le DOM dès l'ouverture — pas idéal au sens strict
  // ARIA (pointer la région entière serait plus exact), mais réel, stable,
  // et sans toucher un composant hors périmètre.
  id: string;
};

// D0 §3 — correctif navigation mobile, PARTAGÉ par l'app (AppShell.tsx) ET
// l'espace client (EspaceClientShell.tsx), puisque les deux sidebars
// partagent `.sidebar` et le même bug (`@media(max-width:900px){.sidebar{display:none}}`
// sans remplaçant). Réutilise ModalShell TEL QUEL (portail, piège de focus,
// fermeture Échap, restauration du focus, verrou de scroll — déjà construits
// et déjà utilisés par ConfirmModal) plutôt que de réimplémenter cette
// mécanique : seule l'HABILLAGE change (panneau plein-hauteur ancré à
// gauche au lieu d'une boîte centrée), via les classes CSS
// `.mobile-nav-drawer-backdrop`/`.mobile-nav-drawer-panel` qui surchargent
// `.modal-shell`/`.modal-shell__surface` (global.css).
export function MobileNavDrawer({ isOpen, onClose, label, children, id }: MobileNavDrawerProps) {
  const titleId = `${id}-title`;

  return (
    <ModalShell
      open={isOpen}
      onClose={onClose}
      labelledBy={titleId}
      className="mobile-nav-drawer-backdrop"
      surfaceClassName="mobile-nav-drawer-panel"
    >
      <h2 id={titleId} className="sr-only">
        {label}
      </h2>

      <button
        type="button"
        className="mobile-nav-drawer__close"
        onClick={onClose}
        aria-label="Fermer le menu"
      >
        <X size={18} />
      </button>

      {children}
    </ModalShell>
  );
}
