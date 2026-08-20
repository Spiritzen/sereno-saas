import { useEffect, useMemo, useState } from "react";
import { listClients } from "../api/clientsApi";
import { listFactures } from "../api/facturesApi";
import { AttentionPanel } from "../components/dashboard/AttentionPanel";
import { DashboardHeader } from "../components/dashboard/DashboardHeader";
import { DashboardKpiGrid } from "../components/dashboard/DashboardKpiGrid";
import { DeadlinesPanel } from "../components/dashboard/DeadlinesPanel";
import { PreflightBanner } from "../components/dashboard/PreflightBanner";
import { QuickActionsBar } from "../components/dashboard/QuickActionsBar";
import { RecentInvoicesCard } from "../components/dashboard/RecentInvoicesCard";
import { useAuth } from "../context/useAuth";
import {
  buildAttentionItems,
  buildDashboardKpis,
  buildRecentFactures,
} from "../lib/dashboardModel";
import type { DashboardStatus } from "../lib/dashboardModel";
import type { Client } from "../types/client";
import type { Facture } from "../types/facture";

const RECENT_FACTURES_LIMIT = 5;

// D1.1 (prompt_claude_code_dashboard_d1_1_regulation_grille_etats_reseau.txt
// §5) — union discriminée explicite : une absence de données pendant
// "loading" ou "error" ne doit JAMAIS être interprétée comme "ready + vide"
// par les panneaux dérivés. `factures`/`clientsById` restent des useState
// séparés (peuplés uniquement en cas de succès), mais AUCUN composant ne doit
// lire leur contenu comme une vérité tant que `status !== "ready"` — c'est ce
// statut, pas la présence de `[]`, qui fait foi. (DashboardStatus lui-même
// vit dans dashboardModel.ts pour éviter un import circulaire avec les
// composants dashboard/*.)
type DashboardLoadState =
  | { status: "loading" }
  | { status: "error"; message: string }
  | { status: "ready" };

// D1 (prompt_claude_code_dashboard_d1_cockpit_final_sereno.txt) — cockpit
// "Final Sereno" avec des données honnêtes. Ce composant ne porte plus que :
// le chargement des données, la coordination loading/error, les projections
// mémoïsées vers dashboardModel.ts, et la composition haut niveau des
// sous-composants dashboard/*. Aucune logique métier ici (tout est dans
// dashboardModel.ts, testé indépendamment).
export function DashboardPage() {
  const { utilisateur } = useAuth();

  const [factures, setFactures] = useState<Facture[]>([]);
  const [clientsById, setClientsById] = useState<Record<string, Client>>({});
  const [loadState, setLoadState] = useState<DashboardLoadState>({ status: "loading" });

  // `today` figé au montage : garantit que le KPI "En retard", le
  // calendrier et le compte à rebours du bandeau restent cohérents entre eux
  // pendant toute la durée de vie de la page, sans dépendre implicitement de
  // `new Date()` dispersé dans plusieurs composants.
  const [today] = useState(() => new Date());

  useEffect(() => {
    // D1.1 : listFactures et listClients sont chargés ensemble (comme en
    // D1) — les panneaux dérivés de factures (KPI, échéances, "à traiter")
    // dépendent tous exclusivement de listFactures ; listClients ne sert
    // qu'à enrichir l'affichage du nom client (repli déjà géré par
    // getClientName si absent). Séparer leurs états réseau exigerait un
    // refactor plus large non demandé par ce micro-sprint (§5 : "ne fais pas
    // de refactor spéculatif ; choisis la correction minimale démontrable") :
    // une erreur sur l'un OU l'autre appel reste donc traitée comme une
    // seule erreur du dashboard, ce qui est déjà honnête (aucun panneau
    // dérivé de factures n'affiche de résultat tant que ce n'est pas ready).
    Promise.all([listFactures(), listClients()])
      .then(([facturesData, clientsData]) => {
        const clientsMap = clientsData.reduce<Record<string, Client>>((accumulator, client) => {
          accumulator[client.id] = client;
          return accumulator;
        }, {});

        setFactures(facturesData);
        setClientsById(clientsMap);
        setLoadState({ status: "ready" });
      })
      .catch((apiError) => {
        setLoadState({
          status: "error",
          message: apiError instanceof Error ? apiError.message : "Impossible de charger le dashboard",
        });
      });
  }, []);

  const kpis = useMemo(() => buildDashboardKpis(factures, today), [factures, today]);

  const recentFactures = useMemo(
    () => buildRecentFactures(factures, RECENT_FACTURES_LIMIT),
    [factures],
  );

  const attentionItems = useMemo(() => buildAttentionItems(factures, today), [factures, today]);

  const status: DashboardStatus = loadState.status;
  const errorMessage = loadState.status === "error" ? loadState.message : null;

  return (
    <>
      <DashboardHeader prenom={utilisateur?.prenom} today={today} />

      {/* D1.1 §4 — silhouette du cockpit : la colonne droite doit démarrer
          à hauteur du bandeau de pré-contrôles (comme dans FinalSereno.png),
          pas seulement à hauteur des factures récentes. PreflightBanner et
          DashboardKpiGrid rejoignent donc .dashboard-main-column au lieu de
          rester pleine largeur au-dessus de la grille : la somme naturelle
          bandeau + KPI + factures équilibre désormais la hauteur naturelle
          échéances + à traiter, ce qui supprime le grand vide vertical
          observé sous la carte des factures sans hauteur artificielle ni
          faux contenu. */}
      <div className="dashboard-cockpit-grid">
        <div className="dashboard-main-column">
          <PreflightBanner today={today} />

          <DashboardKpiGrid kpis={kpis} status={status} />

          <RecentInvoicesCard
            factures={recentFactures}
            clientsById={clientsById}
            status={status}
            errorMessage={errorMessage}
          />
        </div>

        <div className="dashboard-right-rail">
          <DeadlinesPanel
            factures={factures}
            clientsById={clientsById}
            today={today}
            status={status}
          />
          <AttentionPanel items={attentionItems} status={status} />
        </div>
      </div>

      <QuickActionsBar />
    </>
  );
}
