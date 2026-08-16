import { LogOut } from "lucide-react";
import { useState } from "react";
import { useDestinataireAuth } from "../context/useDestinataireAuth";

// Route authentifiée /espace-client — PLACEHOLDER minimal (§4
// execution_espace_client_c1.txt) : les vrais écrans (liste groupée,
// détail, PDF) sont l'étape C2. Prouve juste qu'on reste connecté et qu'on
// peut se déconnecter. La déconnexion ne navigue pas explicitement :
// logout() vide `compte` dans le contexte, ProtectedDestinataireRoute
// (partagé sur tout le sous-arbre /espace-client) redirige au re-rendu.
export function EspaceClientAccueilPage() {
  const { compte, logout } = useDestinataireAuth();
  const [isLoggingOut, setIsLoggingOut] = useState(false);

  async function handleLogout() {
    setIsLoggingOut(true);

    try {
      await logout();
    } finally {
      setIsLoggingOut(false);
    }
  }

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
          <h1>Bienvenue{compte ? ` ${compte.email}` : ""}</h1>
          <p>
            Vos factures arrivent bientôt ici
            {compte && compte.fournisseurs_lies > 0
              ? ` — vous êtes relié à ${compte.fournisseurs_lies} fournisseur${
                  compte.fournisseurs_lies > 1 ? "s" : ""
                }.`
              : "."}
          </p>
        </div>

        <button
          type="button"
          className="secondary-btn"
          disabled={isLoggingOut}
          onClick={() => {
            void handleLogout();
          }}
        >
          <LogOut size={16} />
          {isLoggingOut ? "Déconnexion..." : "Se déconnecter"}
        </button>
      </section>
    </main>
  );
}
