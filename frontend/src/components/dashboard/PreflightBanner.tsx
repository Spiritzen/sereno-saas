import { ShieldCheck } from "lucide-react";
import { computeJoursRestants } from "../../lib/dashboardModel";

const ECHEANCE_RECEPTION_ELECTRONIQUE = new Date("2026-09-01T00:00:00");

type PreflightBannerProps = {
  today: Date;
};

// D1 §4.C — bandeau honnête : "Pré-contrôles actifs" décrit des contrôles
// disponibles avant émission, jamais une connexion PA ou une réception
// active (aucun état backend ne le prouve). Le compte à rebours vise
// l'échéance réglementaire réelle (1er sept. 2026) et ne devient JAMAIS
// négatif : au-delà, "Échéance atteinte" s'affiche à la place.
export function PreflightBanner({ today }: PreflightBannerProps) {
  const joursRestants = computeJoursRestants(ECHEANCE_RECEPTION_ELECTRONIQUE, today);

  return (
    <section className="preflight-banner" aria-label="Pré-contrôles actifs">
      <div className="preflight-banner__content">
        <div className="preflight-banner__icon">
          <ShieldCheck size={20} aria-hidden="true" />
        </div>

        <div className="preflight-banner__text">
          <strong>Pré-contrôles actifs</strong>
          <span>Contrôles disponibles avant émission · format Factur-X</span>
        </div>
      </div>

      <div className="deadline">
        {joursRestants > 0 ? `J-${joursRestants}` : "Échéance atteinte"}
        <br />
        <small>1er sept. 2026</small>
      </div>
    </section>
  );
}
