import type { AuthPayload, LoginInput } from "../types/auth";
import { http } from "./http";

export async function login(input: LoginInput): Promise<AuthPayload> {
  const response = await http.post<AuthPayload>(
    "/auth/login",
    {
      email: input.email,
      password: input.password,
    },
    {
      skipRefresh: true,
    },
  );

  return response.data;
}

export async function me(): Promise<AuthPayload> {
  const response = await http.get<AuthPayload>("/auth/me", {
    skipRefresh: true,
  });

  return response.data;
}

export async function logout(): Promise<void> {
  await http.delete("/auth/logout", {
    skipRefresh: true,
  });
}