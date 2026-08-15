import { Navigate, Route, Routes } from "react-router-dom";
import { ProtectedRoute } from "./components/auth/ProtectedRoute";
import { AppShell } from "./components/layout/AppShell";
import { AvoirDetailPage } from "./pages/AvoirDetailPage";
import { ClientsPage } from "./pages/ClientsPage";
import { DashboardPage } from "./pages/DashboardPage";
import { DevisDetailPage } from "./pages/DevisDetailPage";
import { DevisPage } from "./pages/DevisPage";
import { FactureDetailPage } from "./pages/FactureDetailPage";
import { FacturesPage } from "./pages/FacturesPage";
import { LoginPage } from "./pages/LoginPage";
import { NewCreditNotePage } from "./pages/NewCreditNotePage";
import { NewDevisPage } from "./pages/NewDevisPage";
import { NewInvoicePage } from "./pages/NewInvoicePage";
import { ParametresPage } from "./pages/ParametresPage";
import { PortalPage } from "./pages/PortalPage";

export default function App() {
  return (
    <Routes>
      <Route path="/" element={<Navigate to="/app/dashboard" replace />} />

      <Route path="/login" element={<LoginPage />} />

      {/* Portail destinataire (MVP) — route PUBLIQUE, volontairement PAS
          enveloppée dans ProtectedRoute : aucune session requise, le token
          dans l'URL fait foi (cf. §5 execution_portail_destinataire_mvp.txt). */}
      <Route path="/portail/:token" element={<PortalPage />} />

      <Route
        path="/app/dashboard"
        element={
          <ProtectedRoute>
            <AppShell>
              <DashboardPage />
            </AppShell>
          </ProtectedRoute>
        }
      />

      <Route
        path="/app/factures"
        element={
          <ProtectedRoute>
            <AppShell>
              <FacturesPage />
            </AppShell>
          </ProtectedRoute>
        }
      />

      <Route
        path="/app/factures/new"
        element={
          <ProtectedRoute>
            <AppShell>
              <NewInvoicePage />
            </AppShell>
          </ProtectedRoute>
        }
      />

      <Route
        path="/app/factures/:id"
        element={
          <ProtectedRoute>
            <AppShell>
              <FactureDetailPage />
            </AppShell>
          </ProtectedRoute>
        }
      />

      <Route
        path="/app/factures/:id/avoirs/nouveau"
        element={
          <ProtectedRoute>
            <AppShell>
              <NewCreditNotePage />
            </AppShell>
          </ProtectedRoute>
        }
      />

      <Route
        path="/app/avoirs/:id"
        element={
          <ProtectedRoute>
            <AppShell>
              <AvoirDetailPage />
            </AppShell>
          </ProtectedRoute>
        }
      />

      <Route
        path="/app/devis"
        element={
          <ProtectedRoute>
            <AppShell>
              <DevisPage />
            </AppShell>
          </ProtectedRoute>
        }
      />

      <Route
        path="/app/devis/new"
        element={
          <ProtectedRoute>
            <AppShell>
              <NewDevisPage />
            </AppShell>
          </ProtectedRoute>
        }
      />

      <Route
        path="/app/devis/:id"
        element={
          <ProtectedRoute>
            <AppShell>
              <DevisDetailPage />
            </AppShell>
          </ProtectedRoute>
        }
      />

      <Route
        path="/app/clients"
        element={
          <ProtectedRoute>
            <AppShell>
              <ClientsPage />
            </AppShell>
          </ProtectedRoute>
        }
      />

      <Route
        path="/app/parametres"
        element={
          <ProtectedRoute>
            <AppShell>
              <ParametresPage />
            </AppShell>
          </ProtectedRoute>
        }
      />
    </Routes>
  );
}