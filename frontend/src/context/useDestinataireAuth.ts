import { useContext } from "react";
import {
  DestinataireAuthContext,
  type DestinataireAuthContextValue,
} from "./DestinataireAuthContext";

export function useDestinataireAuth(): DestinataireAuthContextValue {
  const context = useContext(DestinataireAuthContext);

  if (!context) {
    throw new Error("useDestinataireAuth doit être utilisé dans DestinataireAuthProvider");
  }

  return context;
}
