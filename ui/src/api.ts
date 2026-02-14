export interface ConversationPreview {
  id: string;
  title: string;
  snippet: string;
  timestamp: string;
  unread: boolean;
}

export type ExportFormat = "text" | "json" | "sqlite" | "encrypted_package";

export interface ExportRequest {
  format: ExportFormat;
  destination_path: string;
  overwrite: boolean;
  include_attachment_paths: boolean;
  copy_attachments: boolean;
  limit?: number;
  encrypt: boolean;
  passphrase?: string;
}

export interface ApiConfig {
  baseUrl: string;
  token: string;
}

const DEFAULT_CONFIG: ApiConfig = {
  baseUrl: "http://127.0.0.1:8765",
  token: ""
};

export const apiConfig = { ...DEFAULT_CONFIG };

export function setApiConfig(config: Partial<ApiConfig>): void {
  if (config.baseUrl) {
    apiConfig.baseUrl = config.baseUrl;
  }
  if (config.token) {
    apiConfig.token = config.token;
  }
}

async function call<T>(path: string, init?: RequestInit): Promise<T> {
  const headers = new Headers(init?.headers);
  headers.set("Accept", "application/json");
  if (apiConfig.token) {
    headers.set("Authorization", `Bearer ${apiConfig.token}`);
  }
  if (init?.body && !headers.has("Content-Type")) {
    headers.set("Content-Type", "application/json");
  }

  const response = await fetch(`${apiConfig.baseUrl}${path}`, {
    ...init,
    headers
  });

  if (!response.ok) {
    throw new Error(`API request failed with status ${response.status}`);
  }

  return (await response.json()) as T;
}

export async function healthCheck(): Promise<{ ok: boolean }> {
  return call<{ ok: boolean }>("/health");
}
