import { Menu } from "lucide-react";

type TopbarProps = {
  // Le hamburger n'existe QUE sous le breakpoint mobile (masqué au-dessus
  // via CSS, cf. .hamburger-btn dans global.css) ; l'état du tiroir
  // (ouvert/fermé) vit dans AppShell (qui rend aussi le MobileNavDrawer),
  // pas ici — Topbar se contente de déclencher l'ouverture.
  onOpenMobileNav: () => void;
  isMobileNavOpen: boolean;
  drawerId: string;
};

// Correction B (§5 prompt_claude_code_dashboard_d0_1_alignement_shell.txt) —
// UNE SEULE identité utilisateur : le profil (nom/rôle/avatar) et la
// déconnexion, précédemment dupliqués ici en plus du pied de Sidebar, ont
// été RETIRÉS. Sur desktop, cette Topbar ne porte donc plus rien de visible
// (le hamburger lui-même est déjà masqué au-dessus de 900px) : elle est
// masquée visuellement au-delà de ce seuil (`.topbar--app`, cf. global.css)
// pour ne jamais décaler le contenu principal avec une grande barre vide —
// elle reste le SEUL support du header mobile. Le profil et la déconnexion
// restent atteignables sur mobile via le tiroir (Sidebar forceExpanded,
// rendue dans le MobileNavDrawer par AppShell.tsx) : rien n'est perdu,
// seulement plus jamais dupliqué.
export function Topbar({ onOpenMobileNav, isMobileNavOpen, drawerId }: TopbarProps) {
  return (
    <header className="topbar topbar--app">
      <button
        type="button"
        className="hamburger-btn"
        onClick={onOpenMobileNav}
        aria-label="Ouvrir le menu"
        aria-expanded={isMobileNavOpen}
        aria-controls={drawerId}
      >
        <Menu size={20} />
      </button>
    </header>
  );
}
