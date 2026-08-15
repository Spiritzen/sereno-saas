import { Building2, ShieldCheck, WalletCards } from "lucide-react";
import { FecExportPanel } from "../components/FecExportPanel";

export function ParametresPage() {
  return (
    <section className="parametres-page">
      <div className="page-heading">
        <div>
          <span className="page-kicker">Paramètres</span>
          <h1>Paramètres</h1>
          <p>
            Configurez prochainement votre organisation et vos préférences de
            facturation.
          </p>
        </div>
      </div>

      <div className="state-card">
        Cette section est en cours de construction. Les paramètres de votre
        organisation, de votre facturation et de votre future connexion à une
        Plateforme Agréée seront bientôt disponibles ici.
      </div>

      <div className="parametres-cards-grid">
        <article className="kpi-card">
          <div className="parametres-card-header">
            <Building2 size={20} aria-hidden="true" />
            <span className="status info">Bientôt disponible</span>
          </div>
          <strong>Organisation</strong>
          <span>Identité entreprise, coordonnées, informations légales.</span>
        </article>

        <article className="kpi-card">
          <div className="parametres-card-header">
            <WalletCards size={20} aria-hidden="true" />
            <span className="status info">Bientôt disponible</span>
          </div>
          <strong>Facturation</strong>
          <span>
            Régime de TVA, mentions de paiement, préférences documentaires.
          </span>
        </article>

        <article className="kpi-card">
          <div className="parametres-card-header">
            <ShieldCheck size={20} aria-hidden="true" />
            <span className="status info">Bientôt disponible</span>
          </div>
          <strong>Plateforme Agréée</strong>
          <span>Future connexion PA, routage, suivi des transmissions.</span>
        </article>

        <FecExportPanel />
      </div>
    </section>
  );
}
