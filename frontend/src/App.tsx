import { Navigate, Route, Routes } from "react-router-dom";
import { ProtectedRoute } from "./components/auth/ProtectedRoute";
import { AppShell } from "./components/layout/AppShell";
import { DashboardPage } from "./pages/DashboardPage";
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
        path="/app/factures/new"
        element={
          <ProtectedRoute>
            <AppShell>
              <NewInvoicePage />
            </AppShell>
          </ProtectedRoute>
        }
      />
    </Routes>
  );
}