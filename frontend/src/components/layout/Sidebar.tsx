import {
  BarChart3,
  ChevronLeft,
  ChevronRight,
  ClipboardList,
  FileText,
  LogOut,
  Settings,
  Users,
  WalletCards,
} from "lucide-react";
import { useState } from "react";
import { NavLink, useNavigate } from "react-router-dom";
import { SerenoLogo } from "../branding/SerenoLogo";
import { useAuth } from "../../context/useAuth";
import { getUserFullName, getUserInitials, getUserRoleLabel } from "../../utils/userDisplay";

const menuItems = [
  {
    to: "/app/dashboard",
    label: "Dashboard",
    icon: BarChart3,
    end: true,
  },
  {
    to: "/app/factures/new",
    label: "Nouvelle facture",
    icon: FileText,
    end: true,
  },
  {
    to: "/app/devis",
    label: "Devis",
    icon: ClipboardList,
    end: true,
  },
  {
    to: "/app/factures",
    label: "Factures",
    icon: WalletCards,
    end: true,
  },
  {
    to: "/app/clients",
    label: "Clients",
    icon: Users,
    end: true,
  },
  {
    to: "/app/parametres",
    label: "Paramètres",
    icon: Settings,
    end: true,
  },
];

type SidebarProps = {
  // D0 §3 — utilisé par le drawer mobile (MobileNavDrawer, via AppShell) pour
  // toujours afficher la nav complète (icônes + libellés) quel que soit l'état
  // replié/déployé choisi sur desktop : sur un panneau tactile, une sidebar
  // repliée en icônes seules n'a pas de sens. Masque aussi le chevron
  // (rien à replier dans un tiroir déjà dimensionné pour le contenu déployé).
  forceExpanded?: boolean;
};

// D0 §2 execution_dashboard_d0_squelette.txt — DÉPLOYÉE par défaut (libellés
// visibles), toujours rétractable via le chevron existant. Entrées = UNIQUEMENT
// les routes déjà réelles (aucune entrée "Avoirs"/"Paiements"/"Produits &
// services" ajoutée : pas de page derrière aujourd'hui, cf. rapport — un
// bouton mort est explicitement interdit). Identité (logo + marque) et bloc
// profil/déconnexion RÉINTRODUITS en tête/pied — décision explicite de ce
// sprint qui succède à un retrait antérieur motivé par la redondance avec la
// Topbar (cf. commentaire historique dans global.css) : les deux coexistent
// pour l'instant, signalé au rapport.
export function Sidebar({ forceExpanded = false }: SidebarProps) {
  const navigate = useNavigate();
  const { utilisateur, organisation, logout } = useAuth();

  const [isExpandedState, setIsExpandedState] = useState(true);
  const isExpanded = forceExpanded || isExpandedState;

  const initials = getUserInitials(utilisateur);
  const fullName = getUserFullName(utilisateur);
  const roleLabel = getUserRoleLabel(utilisateur);

  async function handleLogout() {
    try {
      await logout();
    } finally {
      navigate("/login", { replace: true });
    }
  }

  return (
    <aside className={`sidebar ${isExpanded ? "expanded" : ""}`}>
      <div className="topbar-brand">
        <SerenoLogo size={38} />

        {isExpanded && (
          <div className="logo-title">
            <strong>Sereno</strong>
            <span>{organisation?.raison_sociale ?? "Facturation électronique conforme"}</span>
          </div>
        )}
      </div>

      {!forceExpanded && (
        <button
          type="button"
          className="sidebar-toggle"
          onClick={() => setIsExpandedState((current) => !current)}
          aria-label={isExpanded ? "Réduire le menu" : "Développer le menu"}
        >
          {isExpanded ? <ChevronLeft size={18} /> : <ChevronRight size={18} />}
          {isExpanded && <span>Réduire</span>}
        </button>
      )}

      <nav className="sidebar-nav" aria-label="Navigation principale">
        {menuItems.map((item) => {
          const Icon = item.icon;

          return (
            <NavLink
              key={item.to}
              to={item.to}
              end={item.end}
              data-label={item.label}
              className={({ isActive }) =>
                `nav-item ${isActive ? "active" : ""}`
              }
            >
              <Icon size={20} />
              <span className="nav-label">{item.label}</span>
            </NavLink>
          );
        })}
      </nav>

      <div className="sidebar-footer">
        <div className="user-chip">
          <span className="avatar">{initials}</span>

          {isExpanded && (
            <div className="user-meta">
              <strong>{fullName}</strong>
              <span>{roleLabel}</span>
            </div>
          )}
        </div>

        <button
          type="button"
          className="logout-btn"
          onClick={() => {
            void handleLogout();
          }}
          aria-label="Se déconnecter"
          title="Se déconnecter"
        >
          <LogOut size={16} />
        </button>
      </div>
    </aside>
  );
}
