import { ShieldCheck } from "lucide-react";
import { useState, type FormEventHandler } from "react";
import { Link, Navigate, useNavigate, useParams } from "react-router-dom";
import { getApiErrorMessage } from "../api/http";
import { useDestinataireAuth } from "../context/useDestinataireAuth";

const MOT_DE_PASSE_LONGUEUR_MIN = 8;

// Route publique /espace-client/activer/:token — le token vient du lien de
// portail (URL), jamais saisi par l'utilisateur. Validation basique côté
// client (format e-mail, longueur mdp, confirmation) : la vérité reste le
// backend (Destinataire::InscriptionsController#create), qui revérifie tout.
export function EspaceClientActivationPage() {
  const { token } = useParams<{ token: string }>();
  const navigate = useNavigate();
  const { activerDepuisLien, isAuthenticated } = useDestinataireAuth();

  const [email, setEmail] = useState("");
  const [motDePasse, setMotDePasse] = useState("");
  const [confirmation, setConfirmation] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [compteExistant, setCompteExistant] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);

  if (isAuthenticated) {
    return <Navigate to="/espace-client" replace />;
  }

  if (!token) {
    return (
      <main className="login-page">
        <section className="login-card">
          <p className="login-error">Ce lien n'est plus valide.</p>
        </section>
      </main>
    );
  }

  const handleSubmit: FormEventHandler<HTMLFormElement> = async (event) => {
    event.preventDefault();

    setError(null);
    setCompteExistant(false);

    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      setError("Indiquez un e-mail valide.");
      return;
    }

    if (motDePasse.length < MOT_DE_PASSE_LONGUEUR_MIN) {
      setError(`Le mot de passe doit contenir au moins ${MOT_DE_PASSE_LONGUEUR_MIN} caractères.`);
      return;
    }

    if (motDePasse !== confirmation) {
      setError("Les deux mots de passe ne correspondent pas.");
      return;
    }

    setIsSubmitting(true);

    try {
      await activerDepuisLien({ token, email, mot_de_passe: motDePasse });
      navigate("/espace-client");
    } catch (activationError) {
      const message = getApiErrorMessage(activationError);

      if (message.includes("connectez-vous")) {
        setCompteExistant(true);
      } else if (message === "Lien invalide ou expiré") {
        setError("Ce lien n'est plus valide.");
      } else {
        setError(message);
      }
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <main className="login-page">
      <section className="login-card">
        <div className="login-brand">
          <div className="brand-mark">S</div>
          <div>
            <strong>Sereno</strong>
            <span>Espace client</span>
          </div>
        </div>

        <div className="login-copy">
          <span className="pa-pill">
            <ShieldCheck size={14} /> Espace sécurisé
          </span>

          <h1>Créer mon espace</h1>
          <p>Choisissez un mot de passe pour accéder à vos factures.</p>
        </div>

        <form className="login-form" onSubmit={handleSubmit}>
          <label>
            Email
            <input
              type="email"
              value={email}
              autoComplete="email"
              placeholder="Votre email"
              onChange={(event) => setEmail(event.target.value)}
            />
          </label>

          <label>
            Mot de passe
            <input
              type="password"
              value={motDePasse}
              autoComplete="new-password"
              placeholder="Choisissez un mot de passe"
              onChange={(event) => setMotDePasse(event.target.value)}
            />
          </label>

          <label>
            Confirmer le mot de passe
            <input
              type="password"
              value={confirmation}
              autoComplete="new-password"
              placeholder="Confirmez le mot de passe"
              onChange={(event) => setConfirmation(event.target.value)}
            />
          </label>

          {error && <p className="login-error">{error}</p>}

          {compteExistant && (
            <p className="login-error">
              Un compte existe déjà avec cet e-mail.{" "}
              <Link to="/espace-client/connexion">Connectez-vous</Link>.
            </p>
          )}

          <button className="primary-btn" type="submit" disabled={isSubmitting}>
            {isSubmitting ? "Création..." : "Créer mon espace"}
          </button>
        </form>
      </section>
    </main>
  );
}
