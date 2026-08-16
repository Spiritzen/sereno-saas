import type { ReactNode } from "react";
import { Navigate } from "react-router-dom";
import { useDestinataireAuth } from "../../context/useDestinataireAuth";

type ProtectedDestinataireRouteProps = {
  children: ReactNode;
};

// JUMEAU de ProtectedRoute.tsx (app) — lit useDestinataireAuth au lieu de
// useAuth, redirige vers /espace-client/connexion au lieu de /login.
export function ProtectedDestinataireRoute({ children }: ProtectedDestinataireRouteProps) {
  const { isAuthenticated, isLoading } = useDestinataireAuth();

  if (isLoading) {
    return (
      <div className="auth-loading">
        <div className="brand-mark">S</div>
        <p>Chargement de votre espace...</p>
      </div>
    );
  }

  if (!isAuthenticated) {
    return <Navigate to="/espace-client/connexion" replace />;
  }

  return children;
}
