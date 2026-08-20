import { FilePlus2, FileText, Settings, Users } from "lucide-react";
import { Link } from "react-router-dom";

// D1 §4.H — 4 destinations RÉELLES uniquement (routes confirmées dans
// App.tsx). Jamais "Avoir" (aucune facture source dans ce contexte), jamais
// "Paiement" (aucune facture cible), jamais "Rapports"/"Produits & services"
// (aucune route frontend n'existe) — aucune route créée juste pour remplir
// la barre.
export function QuickActionsBar() {
  return (
    <nav className="dashboard-quick-actions" aria-label="Actions rapides">
      <Link to="/app/factures/new" className="dashboard-quick-action">
        <span className="dashboard-quick-action__icon">
          <FileText size={18} aria-hidden="true" />
        </span>
        <span>
          <span className="dashboard-quick-action__label">Nouvelle facture</span>
          <span className="dashboard-quick-action__hint">Émettre une facture conforme</span>
        </span>
      </Link>

      <Link to="/app/devis/new" className="dashboard-quick-action">
        <span className="dashboard-quick-action__icon">
          <FilePlus2 size={18} aria-hidden="true" />
        </span>
        <span>
          <span className="dashboard-quick-action__label">Nouveau devis</span>
          <span className="dashboard-quick-action__hint">Préparer une proposition</span>
        </span>
      </Link>

      <Link to="/app/clients" className="dashboard-quick-action">
        <span className="dashboard-quick-action__icon">
          <Users size={18} aria-hidden="true" />
        </span>
        <span>
          <span className="dashboard-quick-action__label">Clients</span>
          <span className="dashboard-quick-action__hint">Gérer les clients</span>
        </span>
      </Link>

      <Link to="/app/parametres" className="dashboard-quick-action">
        <span className="dashboard-quick-action__icon">
          <Settings size={18} aria-hidden="true" />
        </span>
        <span>
          <span className="dashboard-quick-action__label">Paramètres</span>
          <span className="dashboard-quick-action__hint">Configurer votre espace</span>
        </span>
      </Link>
    </nav>
  );
}
