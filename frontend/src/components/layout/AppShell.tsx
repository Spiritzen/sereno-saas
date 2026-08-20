import { useState, type ReactNode } from "react";
import { useLocation } from "react-router-dom";
import { MobileNavDrawer } from "./MobileNavDrawer";
import { Sidebar } from "./Sidebar";
import { Topbar } from "./Topbar";

type AppShellProps = {
  children: ReactNode;
};

const MOBILE_NAV_DRAWER_ID = "app-mobile-nav-drawer";

// Correction A (§4 prompt_claude_code_dashboard_d0_1_alignement_shell.txt) —
// Sidebar/Topbar/main sont désormais des ENFANTS DIRECTS d'une seule grille
// (.sereno-frame, cf. global.css : 2 colonnes, Sidebar en grid-row 1/-1) :
// plus de conteneur .sereno-body intermédiaire formant un second shell dans
// le premier. La sidebar part donc du haut du cadre et le traverse
// entièrement, la Topbar n'appartient plus qu'à la colonne principale.
// MobileNavDrawer n'entre pas dans cette grille : ModalShell le rend via un
// portail (document.body), sa position dans ce JSX n'affecte pas la mise en
// page desktop.
export function AppShell({ children }: AppShellProps) {
  const location = useLocation();
  const [isMobileNavOpen, setIsMobileNavOpen] = useState(false);

  // D0 §3 — ferme le tiroir après toute navigation (clic sur une entrée),
  // sans intercepter chaque NavLink individuellement : la Sidebar reprise
  // dans le tiroir reste EXACTEMENT celle du desktop (mêmes entrées, même
  // rendu), aucune modification de son comportement de clic. Ajustement
  // PENDANT LE RENDU (patron React officiel "Adjusting state when a prop
  // changes"), pas dans un useEffect : eslint react-hooks/set-state-in-effect
  // interdit un setState synchrone en effet (cascading renders) — déjà
  // rencontré et corrigé ainsi ailleurs dans ce projet.
  const [previousPathname, setPreviousPathname] = useState(location.pathname);

  if (location.pathname !== previousPathname) {
    setPreviousPathname(location.pathname);
    setIsMobileNavOpen(false);
  }

  return (
    <div className="sereno-app">
      <div className="sereno-frame">
        <Sidebar />

        <Topbar
          onOpenMobileNav={() => setIsMobileNavOpen(true)}
          isMobileNavOpen={isMobileNavOpen}
          drawerId={`${MOBILE_NAV_DRAWER_ID}-title`}
        />

        <main className="main">{children}</main>

        <MobileNavDrawer
          id={MOBILE_NAV_DRAWER_ID}
          isOpen={isMobileNavOpen}
          onClose={() => setIsMobileNavOpen(false)}
          label="Navigation"
        >
          <Sidebar forceExpanded />
        </MobileNavDrawer>
      </div>
    </div>
  );
}
