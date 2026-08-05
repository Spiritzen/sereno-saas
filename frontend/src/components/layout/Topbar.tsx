import { LogOut } from "lucide-react";
import { Link, useNavigate } from "react-router-dom";
import { useAuth } from "../../context/useAuth";
import {
  getUserFullName,
  getUserInitials,
  getUserRoleLabel,
} from "../../utils/userDisplay";

export function Topbar() {
  const navigate = useNavigate();
  const { utilisateur, organisation, logout } = useAuth();

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
    <header className="topbar">
      <div className="topbar-brand">
        <Link to="/app/dashboard" className="brand-mark" aria-label="Sereno">
          S
        </Link>

        <div className="logo-title">
          <strong>Sereno</strong>
          <span>
            {organisation?.raison_sociale ??
              "Facturation électronique conforme"}
          </span>
        </div>
      </div>

      <div className="topbar-actions">
        <div className="user-chip">
          <span className="avatar">{initials}</span>

          <div className="user-meta">
            <strong>{fullName}</strong>
            <span>{roleLabel}</span>
          </div>
        </div>

        <button
          type="button"
          className="logout-btn"
          onClick={handleLogout}
          aria-label="Se déconnecter"
          title="Se déconnecter"
        >
          <LogOut size={16} />
        </button>
      </div>
    </header>
  );
}