import { ShieldCheck } from "lucide-react";
import { useState, type FormEventHandler } from "react";
import { Navigate, useNavigate } from "react-router-dom";
import { getApiErrorMessage } from "../api/http";
import { useDestinataireAuth } from "../context/useDestinataireAuth";

// Route publique /espace-client/connexion — JUMEAU de LoginPage.tsx (DA
// Celestial réutilisée telle quelle : .login-page/.login-card/.login-brand/
// .login-form/.login-error). Erreurs GÉNÉRIQUES par construction : le
// backend (Destinataire::SessionsController#create) renvoie déjà le MÊME
// message pour un e-mail inconnu et un mot de passe faux — rien à recoder
// ici, juste l'afficher tel quel.
export function EspaceClientConnexionPage() {
  const navigate = useNavigate();
  const { login, isAuthenticated } = useDestinataireAuth();

  const [email, setEmail] = useState("");
  const [motDePasse, setMotDePasse] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  if (isAuthenticated) {
    return <Navigate to="/espace-client" replace />;
  }

  const handleSubmit: FormEventHandler<HTMLFormElement> = async (event) => {
    event.preventDefault();

    setError(null);
    setIsSubmitting(true);

    try {
      await login({ email, mot_de_passe: motDePasse });
      navigate("/espace-client");
    } catch (loginError) {
      setError(getApiErrorMessage(loginError));
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

          <h1>Connexion</h1>
          <p>Retrouvez vos factures auprès de vos fournisseurs Sereno.</p>
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
              autoComplete="current-password"
              placeholder="Votre mot de passe"
              onChange={(event) => setMotDePasse(event.target.value)}
            />
          </label>

          {error && <p className="login-error">{error}</p>}

          <button className="primary-btn" type="submit" disabled={isSubmitting}>
            {isSubmitting ? "Connexion..." : "Se connecter"}
          </button>
        </form>
      </section>
    </main>
  );
}
