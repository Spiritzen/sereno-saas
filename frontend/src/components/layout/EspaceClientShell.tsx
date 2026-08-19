import { LogOut } from "lucide-react";
import type { ReactNode } from "react";
import { useNavigate } from "react-router-dom";
import { useDestinataireAuth } from "../../context/useDestinataireAuth";
import { EspaceClientSidebar } from "./EspaceClientSidebar";

type EspaceClientShellProps = {
  children: ReactNode;
};

// Espace client — JUMEAU structurel d'AppShell.tsx : MÊME conteneur centré
// .sereno-app/.sereno-frame/.sereno-body/.main (largeur max 1180px, marges,
// fond Celestial — valeurs REPRISES telles quelles, aucune inventée).
// Sidebar DÉDIÉE (EspaceClientSidebar, §2
// execution_espace_client_sidebar_pagination_badge.txt) — jamais la Sidebar
// de l'app (nav interne sans rapport). En-tête minimal (brand + "Espace
// client" + déconnexion) au lieu de la Topbar app complète : pas
// d'utilisateur/organisation/rôle à afficher ici, seulement l'e-mail du
// compte destinataire.
// N'enveloppe QUE les écrans AUTHENTIFIÉS (liste, fournisseurs, paramètres,
// détail) — connexion et activation gardent leur propre .login-page/
// .login-card, déjà JUMEAU de LoginPage.tsx (déjà centré, déjà padded,
// rendu hors AppShell dans App.tsx) : les envelopper ici créerait un double
// cadre inédit, sans précédent dans l'app, et un bouton "Se déconnecter" y
// serait incohérent (aucune session à quitter avant connexion).
export function EspaceClientShell({ children }: EspaceClientShellProps) {
  const navigate = useNavigate();
  const { compte, logout } = useDestinataireAuth();

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
        <header className="topbar">
          <div className="topbar-brand">
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

        <div className="sereno-body">
          <EspaceClientSidebar />

          <main className="main">{children}</main>
        </div>
      </div>
    </div>
  );
}
