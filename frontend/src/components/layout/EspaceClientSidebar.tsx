import { ChevronLeft, ChevronRight, Settings, Users, WalletCards } from "lucide-react";
import { useState } from "react";
import { NavLink } from "react-router-dom";

// Espace client — sidebar DÉDIÉE (§2 execution_espace_client_sidebar_pagination_badge.txt),
// INSPIRÉE du MÉCANISME de Sidebar.tsx (app) — même classes CSS (.sidebar/
// .sidebar-toggle/.sidebar-nav/.nav-item/.nav-label), même toggle chevron —
// mais un composant SÉPARÉ : la nav de l'app (Dashboard, Devis, Clients...)
// n'a pas de sens ici, et Sidebar.tsx reste réservé au sous-arbre /app/*.
const menuItems = [
  {
    to: "/espace-client",
    label: "Mes factures",
    icon: WalletCards,
    end: true,
  },
  {
    to: "/espace-client/fournisseurs",
    label: "Mes fournisseurs",
    icon: Users,
    end: true,
  },
  {
    to: "/espace-client/parametres",
    label: "Paramètres",
    icon: Settings,
    end: true,
  },
];

export function EspaceClientSidebar() {
  // Pas de persistance (localStorage) : Sidebar.tsx (app) n'en a pas non
  // plus aujourd'hui (useState(false) nu) — cohérent avec l'existant plutôt
  // qu'une invention. Si une persistance est ajoutée un jour ici, elle devra
  // utiliser une clé PRÉFIXÉE "sereno.destinataire." (jamais celle de l'app).
  const [isExpanded, setIsExpanded] = useState(false);

  return (
    <aside className={`sidebar ${isExpanded ? "expanded" : ""}`}>
      <button
        type="button"
        className="sidebar-toggle"
        onClick={() => setIsExpanded((current) => !current)}
        aria-label={isExpanded ? "Réduire le menu" : "Développer le menu"}
      >
        {isExpanded ? <ChevronLeft size={18} /> : <ChevronRight size={18} />}
        {isExpanded && <span>Réduire</span>}
      </button>

      <nav className="sidebar-nav" aria-label="Navigation espace client">
        {menuItems.map((item) => {
          const Icon = item.icon;

          return (
            <NavLink
              key={item.to}
              to={item.to}
              end={item.end}
              data-label={item.label}
              className={({ isActive }) => `nav-item ${isActive ? "active" : ""}`}
            >
              <Icon size={20} />
              <span className="nav-label">{item.label}</span>
            </NavLink>
          );
        })}
      </nav>
    </aside>
  );
}
