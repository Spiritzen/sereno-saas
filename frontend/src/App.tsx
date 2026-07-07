import { Navigate, Route, Routes } from "react-router-dom";
import { ProtectedRoute } from "./components/auth/ProtectedRoute";
import { AppShell } from "./components/layout/AppShell";
import { ClientsPage } from "./pages/ClientsPage";
import { DashboardPage } from "./pages/DashboardPage";
import { FactureDetailPage } from "./pages/FactureDetailPage";
import { FacturesPage } from "./pages/FacturesPage";
import { LoginPage } from "./pages/LoginPage";
import { NewInvoicePage } from "./pages/NewInvoicePage";

export default function App() {
  return (
    <Routes>
      <Route path="/" element={<Navigate to="/app/dashboard" replace />} />

      <Route path="/login" element={<LoginPage />} />

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
        path="/app/clients"
        element={
          <ProtectedRoute>
            <AppShell>
              <ClientsPage />
            </AppShell>
          </ProtectedRoute>
        }
      />
    </Routes>
  );
}