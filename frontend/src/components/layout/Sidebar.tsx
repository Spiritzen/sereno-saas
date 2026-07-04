import {
  BarChart3,
  ChevronLeft,
  ChevronRight,
  FileText,
  Settings,
  Users,
  WalletCards,
} from "lucide-react";
import { useState } from "react";
import { NavLink } from "react-router-dom";

const menuItems = [
  {
    to: "/app/dashboard",
    label: "Dashboard",
    icon: BarChart3,
  },
  {
    to: "/app/factures/new",
    label: "Nouvelle facture",
    icon: FileText,
  },
  {
    to: "/app/clients",
    label: "Clients",
    icon: Users,
  },
  {
    to: "/app/factures",
    label: "Factures",
    icon: WalletCards,
  },
  {
    to: "/app/parametres",
    label: "Paramètres",
    icon: Settings,
  },
];

export function Sidebar() {
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

      <nav className="sidebar-nav" aria-label="Navigation principale">
        {menuItems.map((item) => {
          const Icon = item.icon;

          return (
            <NavLink
              key={item.to}
              to={item.to}
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
    </aside>
  );
}