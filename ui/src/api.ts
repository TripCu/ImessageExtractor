export interface ConversationPreview {
  id: string;
  title: string;
  snippet: string;
  timestamp: string;
  unread: boolean;
}

export interface AttachmentRecord {
  filename: string;
  mime_type?: string | null;
  path?: string | null;
}

export interface MessageRecord {
  id: number;
  timestamp: string;
  sender: string;
  text?: string | null;
  is_from_me: boolean;
  attachments: AttachmentRecord[];
}

export interface ConversationThread {
  id: number;
  title: string;
  participants: string[];
  messages: MessageRecord[];
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

export interface ExportResponse {
  status: string;
  output_path: string;
  message_count: number;
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
    headers,
    cache: "no-store"
  });

  if (!response.ok) {
    let detail = `API request failed with status ${response.status}`;
    try {
      const payload = (await response.json()) as {
        error?: { detail?: string };
      };
      if (payload.error?.detail) {
        detail = payload.error.detail;
      }
    } catch {
      // Ignore non-JSON errors.
    }
    throw new Error(detail);
  }

  return (await response.json()) as T;
}

export async function healthCheck(): Promise<{ ok: boolean }> {
  return call<{ ok: boolean }>("/health");
}

export async function listConversations(search: string): Promise<ConversationPreview[]> {
  const query = new URLSearchParams();
  if (search.trim()) {
    query.set("search", search.trim());
  }

  const response = await call<{ conversations: Array<Omit<ConversationPreview, "id"> & { id: number | string }> }>(
    `/conversations?${query.toString()}`
  );
  return response.conversations.map((conversation) => ({
    ...conversation,
    id: String(conversation.id)
  }));
}

export async function getConversation(
  id: string,
  options?: { limit?: number; before?: number }
): Promise<ConversationThread> {
  const query = new URLSearchParams();
  if (options?.limit) {
    query.set("limit", String(options.limit));
  }
  if (options?.before) {
    query.set("before", String(options.before));
  }

  const response = await call<{ conversation: ConversationThread }>(
    `/conversations/${encodeURIComponent(id)}?${query.toString()}`
  );
  return response.conversation;
}

export async function exportConversation(id: string, payload: ExportRequest): Promise<ExportResponse> {
  return call<ExportResponse>(`/conversations/${encodeURIComponent(id)}/export`, {
    method: "POST",
    body: JSON.stringify(payload)
  });
}
