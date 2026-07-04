export function normalizeCollection<T>(
  payload: unknown,
  resourceKey: string,
): T[] {
  if (Array.isArray(payload)) {
    return payload as T[];
  }

  if (isRecord(payload)) {
    const resourceValue = payload[resourceKey];

    if (Array.isArray(resourceValue)) {
      return resourceValue as T[];
    }

    if (Array.isArray(payload.data)) {
      return payload.data as T[];
    }

    if (Array.isArray(payload.items)) {
      return payload.items as T[];
    }
  }

  throw new Error(`Réponse API inattendue pour la collection "${resourceKey}"`);
}

export function normalizeResource<T>(
  payload: unknown,
  resourceKey: string,
): T {
  if (isRecord(payload)) {
    const resourceValue = payload[resourceKey];

    if (isRecord(resourceValue)) {
      return resourceValue as T;
    }

    if (isRecord(payload.data)) {
      return payload.data as T;
    }
  }

  return payload as T;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
