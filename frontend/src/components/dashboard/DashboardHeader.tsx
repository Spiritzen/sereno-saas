import { Plus } from "lucide-react";
import { Link } from "react-router-dom";
import { buildGreeting, formatToday } from "../../lib/dashboardModel";

type DashboardHeaderProps = {
  prenom: string | undefined;
  today: Date;
};

// D1 §4.A — en-tête réel : salutation + CTA réel vers /app/factures/new.
// Pas de recherche, pas de cloche, pas de pastille "PA connectée" (aucun
// état backend ne le prouve, cf. §2 reconnaissance). La date reste discrète
// (texte meta sous le sous-titre), jamais un eyebrow dominant au-dessus du
// titre — c'est le SEUL h1 de la page (§8 accessibilité).
export function DashboardHeader({ prenom, today }: DashboardHeaderProps) {
  return (
    <header className="dashboard-header">
      <div className="dashboard-header__intro">
        <h1>{buildGreeting(prenom)} 👋</h1>
        <p className="dashboard-header__subtitle">Votre cockpit de facturation est prêt.</p>
        <p className="dashboard-header__date">{formatToday(today)}</p>
      </div>

      <Link to="/app/factures/new" className="primary-btn">
        <Plus size={16} aria-hidden="true" /> Nouvelle facture conforme
      </Link>
    </header>
  );
}
