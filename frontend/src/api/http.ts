import axios, { AxiosError, type InternalAxiosRequestConfig } from "axios";

declare module "axios" {
  export interface AxiosRequestConfig {
    skipRefresh?: boolean;
  }

  export interface InternalAxiosRequestConfig {
    skipRefresh?: boolean;
    _retry?: boolean;
  }
}

const API_BASE_URL =
  import.meta.env.VITE_API_BASE_URL ?? "http://localhost:3000/api/v1";

export const http = axios.create({
  baseURL: API_BASE_URL,
  withCredentials: true,
  headers: {
    "Content-Type": "application/json",
  },
});

http.interceptors.response.use(
  (response) => response,
  async (error: AxiosError) => {
    const originalRequest = error.config as
      | InternalAxiosRequestConfig
      | undefined;

    if (
      error.response?.status === 401 &&
      originalRequest &&
      !originalRequest._retry &&
      !originalRequest.skipRefresh
    ) {
      originalRequest._retry = true;

      try {
        await http.post("/auth/refresh", {}, { skipRefresh: true });
        return http(originalRequest);
      } catch {
        return Promise.reject(error);
      }
    }

    return Promise.reject(error);
  },
);

export function getApiErrorMessage(error: unknown) {
  if (axios.isAxiosError(error)) {
    const data = error.response?.data as
      | { error?: string; message?: string }
      | undefined;

    return data?.error ?? data?.message ?? `Erreur API ${error.response?.status}`;
  }

  if (error instanceof Error) {
    return error.message;
  }

  return "Erreur inconnue";
}