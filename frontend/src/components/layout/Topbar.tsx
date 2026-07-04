import { LogOut, ShieldCheck } from "lucide-react";
import { Link, useNavigate } from "react-router-dom";
import { useAuth } from "../../context/useAuth";

const ROLE_LABELS = {
  super_admin: "Super admin",
  owner: "Owner",
  comptable: "Comptable",
  membre: "Membre",
} as const;

export function Topbar() {
  const navigate = useNavigate();
  const { utilisateur, organisation, logout } = useAuth();

  const initials = getInitials(
    utilisateur?.prenom,
    utilisateur?.nom,
    utilisateur?.email,
  );

  const fullName = utilisateur
    ? `${utilisateur.prenom} ${utilisateur.nom}`.trim()
    : "Utilisateur";

  const roleLabel = utilisateur ? ROLE_LABELS[utilisateur.role] : "Connecté";

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
        <span className="pa-pill">
          <ShieldCheck size={14} /> PA connectée
        </span>

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

function getInitials(prenom?: string, nom?: string, email?: string) {
  const first = prenom?.[0] ?? "";
  const last = nom?.[0] ?? "";

  const initials = `${first}${last}`.toUpperCase();

  if (initials.length > 0) {
    return initials;
  }

  return email?.slice(0, 2).toUpperCase() ?? "SC";
}