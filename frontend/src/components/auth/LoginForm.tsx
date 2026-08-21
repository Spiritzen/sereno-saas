import { useState, type FormEventHandler } from "react";
import { getApiErrorMessage } from "../../api/http";
import { useAuth } from "../../context/useAuth";

type LoginFormProps = {
  // Appelé APRÈS que login() a réellement hydraté la session (jamais avant :
  // la navigation ne doit jamais devancer l'état réel d'authentification).
  onSuccess: () => void;
  // R3 (§10) — LoginPage ET AuthModal composent ce même formulaire avec leur
  // propre habillage (page vs modale) ; le premier champ reçoit le focus
  // initial différemment selon le contexte (ModalShell gère déjà le focus
  // initial de la modale via `initialFocusRef` côté AuthModal — la page, elle,
  // n'a pas besoin de ce comportement) : `autoFocus` reste désactivé par
  // défaut pour ne jamais entrer en conflit avec la gestion de focus de
  // ModalShell.
};

// R3 (§10) — UNE SEULE logique de soumission/validation/erreur de connexion,
// partagée par /login (LoginPage) et la modale (AuthModal). Extrait tel quel
// depuis l'ancien LoginPage.tsx : aucun champ, aucun message, aucun
// comportement de validation n'a changé — seule l'habillage (page/modale)
// diffère désormais entre les deux appelants.
export function LoginForm({ onSuccess }: LoginFormProps) {
  const { login } = useAuth();

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleSubmit: FormEventHandler<HTMLFormElement> = async (event) => {
    event.preventDefault();

    if (isSubmitting) {
      return;
    }

    setError(null);
    setIsSubmitting(true);

    try {
      await login({ email, password });
      onSuccess();
    } catch (loginError) {
      setError(getApiErrorMessage(loginError));
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <form className="login-form" onSubmit={handleSubmit} noValidate>
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

      {error && (
        <p className="login-error" role="alert">
          {error}
        </p>
      )}

      <button className="primary-btn" type="submit" disabled={isSubmitting}>
        {isSubmitting ? "Connexion..." : "Se connecter"}
      </button>
    </form>
  );
}
