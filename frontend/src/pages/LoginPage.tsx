import { ShieldCheck } from "lucide-react";
import { Navigate, useNavigate } from "react-router-dom";
import { LoginForm } from "../components/auth/LoginForm";
import { useAuth } from "../context/useAuth";

// R3 (prompt_claude_code_inscription_owner_frontend_r3.txt §10) — le
// formulaire lui-même (champs/validation/soumission/erreur) vit désormais
// dans LoginForm, partagé avec AuthModal. Cette page ne fournit plus que son
// habillage (page dédiée + navigation) — comportement inchangé pour un
// visiteur : `/login` reste une route publique fonctionnelle de secours et
// de deep-link, un OWNER déjà connecté est toujours renvoyé au cockpit.
export function LoginPage() {
  const navigate = useNavigate();
  const { isAuthenticated } = useAuth();

  if (isAuthenticated) {
    return <Navigate to="/app/dashboard" replace />;
  }

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

        <LoginForm onSuccess={() => navigate("/app/dashboard")} />
      </section>
    </main>
  );
}
