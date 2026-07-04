import { ShieldCheck } from "lucide-react";
import { useState, type FormEventHandler } from "react";
import { Navigate, useNavigate } from "react-router-dom";
import { getApiErrorMessage } from "../api/http";
import { useAuth } from "../context/useAuth";

export function LoginPage() {
  const navigate = useNavigate();
  const { login, isAuthenticated } = useAuth();

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  if (isAuthenticated) {
    return <Navigate to="/app/dashboard" replace />;
  }

  const handleSubmit: FormEventHandler<HTMLFormElement> = async (event) => {
    event.preventDefault();

    setError(null);
    setIsSubmitting(true);

    try {
      await login({ email, password });
      navigate("/app/dashboard");
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
            <span>Facturation électronique conforme</span>
          </div>
        </div>

        <div className="login-copy">
          <span className="pa-pill">
            <ShieldCheck size={14} /> Espace sécurisé
          </span>

          <h1>Connexion</h1>
          <p>
            Accédez à votre cockpit conformité, vos clients et vos factures
            Factur-X.
          </p>
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
              value={password}
              autoComplete="current-password"
              placeholder="Votre mot de passe"
              onChange={(event) => setPassword(event.target.value)}
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