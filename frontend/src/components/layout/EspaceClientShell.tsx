import { LogOut, Menu } from "lucide-react";
import { useState, type ReactNode } from "react";
import { useLocation, useNavigate } from "react-router-dom";
import { useDestinataireAuth } from "../../context/useDestinataireAuth";
import { EspaceClientSidebar } from "./EspaceClientSidebar";
import { MobileNavDrawer } from "./MobileNavDrawer";

type EspaceClientShellProps = {
  children: ReactNode;
};

// Espace client — JUMEAU structurel d'AppShell.tsx : MÊME conteneur
// .sereno-app/.sereno-frame/.main (marges, fond Celestial — valeurs REPRISES
// telles quelles, aucune inventée), MÊME grille (Sidebar en grid-row 1/-1,
// cf. AppShell.tsx et global.css — correctif structurel D0.1 partagé, pas
// une DA propriétaire imposée : la sidebar pleine hauteur est un correctif
// de mise en page, pas une couleur/un token). Sidebar DÉDIÉE
// (EspaceClientSidebar, §2 execution_espace_client_sidebar_pagination_badge.txt)
// — jamais la Sidebar de l'app. En-tête minimal (brand + "Espace client" +
// compte + déconnexion), gardé VISIBLE sur desktop (contrairement à la
// Topbar app) : contrairement à celle-ci, ce contenu n'est dupliqué NULLE
// PART ailleurs (EspaceClientSidebar ne porte pas de pied profil) — rien à
// retirer ici, cf. rapport D0.1.
// N'enveloppe QUE les écrans AUTHENTIFIÉS (liste, fournisseurs, paramètres,
// détail) — connexion et activation gardent leur propre .login-page/
// .login-card, déjà JUMEAU de LoginPage.tsx (déjà centré, déjà padded,
// rendu hors AppShell dans App.tsx) : les envelopper ici créerait un double
// cadre inédit, sans précédent dans l'app, et un bouton "Se déconnecter" y
// serait incohérent (aucune session à quitter avant connexion).
const MOBILE_NAV_DRAWER_ID = "espace-client-mobile-nav-drawer";

export function EspaceClientShell({ children }: EspaceClientShellProps) {
  const navigate = useNavigate();
  const location = useLocation();
  const { compte, logout } = useDestinataireAuth();

  const [isMobileNavOpen, setIsMobileNavOpen] = useState(false);

  // Ajustement PENDANT LE RENDU (patron React officiel "Adjusting state when
  // a prop changes"), pas dans un useEffect — cf. le même correctif et sa
  // justification complète dans AppShell.tsx.
  const [previousPathname, setPreviousPathname] = useState(location.pathname);

  if (location.pathname !== previousPathname) {
    setPreviousPathname(location.pathname);
    setIsMobileNavOpen(false);
  }

  // logout() (contexte) avale déjà tout échec backend et nettoie l'état
  // local dans tous les cas (fix_espace_client_auth_deconnexion) — la
  // redirection peut donc suivre directement, sans try/finally défensif.
  async function handleLogout() {
    await logout();
    navigate("/espace-client/connexion", { replace: true });
  }

  return (
    <div className="sereno-app">
      <div className="sereno-frame">
        <EspaceClientSidebar />

        <header className="topbar">
          <div className="topbar-brand">
            <button
              type="button"
              className="hamburger-btn"
              onClick={() => setIsMobileNavOpen(true)}
              aria-label="Ouvrir le menu"
              aria-expanded={isMobileNavOpen}
              aria-controls={`${MOBILE_NAV_DRAWER_ID}-title`}
            >
              <Menu size={20} />
            </button>

            <div className="brand-mark">S</div>
            <div className="logo-title">
              <strong>Sereno</strong>
              <span>Espace client</span>
            </div>
          </div>

          <div className="topbar-actions">
            {compte && (
              <div className="user-chip">
                <div className="user-meta">
                  <strong>{compte.email}</strong>
                </div>
              </div>
            )}

            <button
              type="button"
              className="secondary-btn"
              onClick={() => {
                void handleLogout();
              }}
            >
              <LogOut size={16} />
              Se déconnecter
            </button>
          </div>
        </header>

        <main className="main">{children}</main>

        <MobileNavDrawer
          id={MOBILE_NAV_DRAWER_ID}
          isOpen={isMobileNavOpen}
          onClose={() => setIsMobileNavOpen(false)}
          label="Navigation espace client"
        >
          <EspaceClientSidebar forceExpanded />
        </MobileNavDrawer>
      </div>
    </div>
  );
}
