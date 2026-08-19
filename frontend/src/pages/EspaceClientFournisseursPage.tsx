import { ArrowRight } from "lucide-react";
import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { listerFournisseurs } from "../api/destinataireApi";
import { estErreurNonAuthentifie } from "../api/destinataireHttp";
import { getApiErrorMessage } from "../api/http";
import type { EspaceClientFournisseurEntree } from "../types/espaceClient";

// Route authentifiée /espace-client/fournisseurs (§2
// execution_espace_client_sidebar_pagination_badge.txt) — vue RÉELLE, pas
// une coquille : GET /destinataire/fournisseurs (Destinataire::FournisseursController),
// dérivé du MÊME groupement par fournisseur que la liste des factures. Un
// clic filtre la liste des factures sur ce fournisseur (bonus §2 — direct,
// via /espace-client?fournisseur=<id>, lu par EspaceClientFacturesPage).
export function EspaceClientFournisseursPage() {
  const [entrees, setEntrees] = useState<EspaceClientFournisseurEntree[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [retryCount, setRetryCount] = useState(0);

  useEffect(() => {
    let ignore = false;

    void listerFournisseurs()
      .then((data) => {
        if (ignore) {
          return;
        }

        setEntrees(data);
        setError(null);
      })
      .catch((apiError) => {
        if (ignore) {
          return;
        }

        // fix_espace_client_auth_deconnexion — même discipline que les
        // autres écrans : un 401 est géré par le contexte + le garde,
        // jamais affiché comme une erreur de contenu de page.
        if (estErreurNonAuthentifie(apiError)) {
          return;
        }

        setError(getApiErrorMessage(apiError));
      })
      .finally(() => {
        if (!ignore) {
          setIsLoading(false);
        }
      });

    return () => {
      ignore = true;
    };
  }, [retryCount]);

  function handleRetry() {
    setIsLoading(true);
    setRetryCount((count) => count + 1);
  }

  return (
    <section className="factures-page">
      <div className="page-heading">
        <div>
          <span className="page-kicker">Espace client</span>
          <h1>Mes fournisseurs</h1>
          <p>Les organisations Sereno auprès desquelles vous recevez des factures.</p>
        </div>
      </div>

      {isLoading && <div className="state-card">Chargement de vos fournisseurs...</div>}

      {!isLoading && error && (
        <div className="state-card error">
          {error}
          <div className="invoice-actions-row" style={{ marginTop: 12 }}>
            <button type="button" className="secondary-btn" onClick={handleRetry}>
              Réessayer
            </button>
          </div>
        </div>
      )}

      {!isLoading && !error && entrees.length === 0 && (
        <div className="state-card">Aucun fournisseur pour le moment.</div>
      )}

      {!isLoading &&
        !error &&
        entrees.map((entree) => (
          // .client-choice-card/.client-choice-avatar — déjà la carte
          // "élément de liste cliquable" de la DA (NewInvoicePage, choix du
          // client), reprise TELLE QUELLE plutôt qu'un nouveau composant.
          <Link
            key={entree.fournisseur.id}
            to={`/espace-client?fournisseur=${entree.fournisseur.id}`}
            className="client-choice-card"
            style={{ textDecoration: "none" }}
          >
            {entree.fournisseur.logo_url ? (
              <img
                src={entree.fournisseur.logo_url}
                alt=""
                className="client-choice-avatar"
                style={{ objectFit: "contain" }}
              />
            ) : (
              <span className="client-choice-avatar">{entree.fournisseur.raison_sociale.slice(0, 2)}</span>
            )}

            <div style={{ flex: 1 }}>
              <strong>{entree.fournisseur.raison_sociale}</strong>
              <span>
                {entree.nombre_factures} facture{entree.nombre_factures > 1 ? "s" : ""}
              </span>
            </div>

            <ArrowRight size={18} />
          </Link>
        ))}
    </section>
  );
}
