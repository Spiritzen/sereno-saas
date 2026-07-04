import type { ReactNode } from "react";
import { Navigate } from "react-router-dom";
import { useAuth } from "../../context/useAuth";

type ProtectedRouteProps = {
  children: ReactNode;
};

export function ProtectedRoute({ children }: ProtectedRouteProps) {
  const { isAuthenticated, isLoading } = useAuth();

  if (isLoading) {
    return (
      <div className="auth-loading">
        <div className="brand-mark">S</div>
        <p>Chargement de votre espace Sereno...</p>
      </div>
    );
  }

  if (!isAuthenticated) {
    return <Navigate to="/login" replace />;
  }

  return children;
}
