import { useState, type FormEventHandler } from "react";
import { useNavigate } from "react-router-dom";
import { supprimerCompte } from "../api/destinataireApi";
import { getApiErrorMessage } from "../api/http";
import { useDestinataireAuth } from "../context/useDestinataireAuth";

// Route authentifiée /espace-client/parametres (§2
// execution_espace_client_sidebar_pagination_badge.txt) — vue RÉELLE, pas
// une coquille : e-mail depuis le compte déjà chargé par
// DestinataireAuthProvider (GET /destinataire/moi au bootstrap, aucun appel
// redondant ici), suppression de compte branchée sur DELETE
// /destinataire/compte (étape A, confirmation par mot de passe déjà exigée
// côté backend — jamais recontrôlée ici, juste transmise).
export function EspaceClientParametresPage() {
  const navigate = useNavigate();
  const { compte, logout } = useDestinataireAuth();

  const [confirmationOuverte, setConfirmationOuverte] = useState(false);
  const [motDePasse, setMotDePasse] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  function handleOuvrirConfirmation() {
    setConfirmationOuverte(true);
  }

  function handleAnnuler() {
    setConfirmationOuverte(false);
    setMotDePasse("");
    setError(null);
  }

  const handleSupprimer: FormEventHandler<HTMLFormElement> = async (event) => {
    event.preventDefault();

    setIsSubmitting(true);
    setError(null);

    try {
      await supprimerCompte(motDePasse);
      await logout();
      navigate("/espace-client/connexion", { replace: true });
    } catch (apiError) {
      setError(getApiErrorMessage(apiError));
      setIsSubmitting(false);
    }
  };

  return (
    <section className="factures-page">
      <div className="page-heading">
        <div>
          <span className="page-kicker">Espace client</span>
          <h1>Paramètres</h1>
          <p>Vos informations de connexion et la gestion de votre compte.</p>
        </div>
      </div>

      <div className="quick-step-card">
        <div>
          <span className="page-kicker">Compte</span>
          <h2 style={{ margin: "6px 0" }}>E-mail</h2>
          <p style={{ margin: 0, color: "var(--color-text-secondary)" }}>{compte?.email ?? "—"}</p>
        </div>
      </div>

      <div className="quick-step-card">
        <div>
          <span className="page-kicker">Zone dangereuse</span>
          <h2 style={{ margin: "6px 0" }}>Supprimer mon compte</h2>
          <p style={{ margin: 0, color: "var(--color-text-secondary)" }}>
            Cette action est définitive : votre compte, vos sessions et vos liens vers vos
            fournisseurs seront supprimés. Vos factures elles-mêmes ne sont pas affectées.
          </p>
        </div>

        {!confirmationOuverte && (
          <button type="button" className="danger-btn" onClick={handleOuvrirConfirmation}>
            Supprimer mon compte
          </button>
        )}

        {confirmationOuverte && (
          <form className="line-form" onSubmit={handleSupprimer}>
            <label>
              Confirmez avec votre mot de passe
              <input
                type="password"
                value={motDePasse}
                autoComplete="current-password"
                placeholder="Votre mot de passe"
                onChange={(event) => setMotDePasse(event.target.value)}
              />
            </label>

            {error && <p className="login-error">{error}</p>}

            <div className="invoice-actions-row">
              <button type="button" className="secondary-btn" disabled={isSubmitting} onClick={handleAnnuler}>
                Annuler
              </button>

              <button type="submit" className="danger-btn" disabled={isSubmitting}>
                {isSubmitting ? "Suppression..." : "Confirmer la suppression"}
              </button>
            </div>
          </form>
        )}
      </div>
    </section>
  );
}
