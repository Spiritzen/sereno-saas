import { ListChecks } from "lucide-react";
import { Link } from "react-router-dom";
import type { AttentionItem, DashboardStatus } from "../../lib/dashboardModel";
import { SectionHeading } from "../SectionHeading";

type AttentionPanelProps = {
  items: AttentionItem[];
  status: DashboardStatus;
};

// D1 §4.G — "À traiter" (JAMAIS "Activité récente" : aucun endpoint
// d'activité cross-document n'existe aujourd'hui, cf. §2 reconnaissance).
// Catégories dérivées des factures déjà chargées uniquement, jamais une
// date relative inventée ("il y a 2 heures" sans événement réel).
//
// D1.1 §5 — "Rien d'urgent pour le moment" est une conclusion métier : elle
// ne s'affiche que lorsque `status === "ready"` et que la liste est
// réellement vide. Pendant loading/error, un texte neutre distinct évite de
// transformer une panne réseau en fausse tranquillité.
export function AttentionPanel({ items, status }: AttentionPanelProps) {
  return (
    <section
      className="dashboard-panel"
      aria-label="À traiter"
      aria-busy={status === "loading" ? true : undefined}
    >
      <SectionHeading icon={<ListChecks size={18} aria-hidden="true" />} title="À traiter" />

      {status === "loading" && <div className="state-card">Chargement…</div>}

      {status === "error" && <div className="state-card error">Données indisponibles</div>}

      {status === "ready" && items.length === 0 && (
        <div className="state-card">Rien d'urgent pour le moment.</div>
      )}

      {status === "ready" && items.length > 0 && (
        <ul className="dashboard-attention-list">
          {items.map((item) => (
            <li key={item.category}>
              <Link to="/app/factures" className="dashboard-attention-item">
                <span>{item.label}</span>
                <span className="dashboard-attention-item__count">{item.count}</span>
              </Link>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}
