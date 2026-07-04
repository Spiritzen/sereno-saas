import type { ReactNode } from "react";
import { Sidebar } from "./Sidebar";
import { Topbar } from "./Topbar";

type AppShellProps = {
  children: ReactNode;
};

export function AppShell({ children }: AppShellProps) {
  return (
    <div className="sereno-app">
      <div className="sereno-frame">
        <Topbar />

        <div className="sereno-body">
          <Sidebar />

          <main className="main">{children}</main>
        </div>
      </div>
    </div>
  );
}