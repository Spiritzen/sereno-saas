import { useContext } from "react";
import { AuthContext, type AuthContextValue } from "./AuthContext";

export function useAuth(): AuthContextValue {
  const context = useContext(AuthContext);

  if (!context) {
    throw new Error("useAuth doit être utilisé dans AuthProvider");
  }

  return context;
}
