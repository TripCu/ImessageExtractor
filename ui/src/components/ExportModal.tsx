import { useEffect, useMemo, useState } from "react";
import type { FormEvent } from "react";

import type { ExportFormat, ExportRequest } from "../api";

interface ExportModalProps {
  open: boolean;
  conversationTitle: string;
  initialFormat: ExportFormat;
  onClose: () => void;
  onSubmit: (payload: ExportRequest) => Promise<void>;
  submitting: boolean;
  error: string | null;
}

const FORMATS: Array<{ value: ExportFormat; label: string }> = [
  { value: "text", label: "Text" },
  { value: "json", label: "JSON" },
  { value: "sqlite", label: "SQLite" },
  { value: "encrypted_package", label: "Encrypted" }
];

function extensionFor(format: ExportFormat): string {
  switch (format) {
    case "text":
      return "txt";
    case "json":
      return "json";
    case "sqlite":
      return "sqlite";
    default:
      return "imexport";
  }
}

function slugify(value: string): string {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 48) || "conversation";
}

function buildDefaultDestination(title: string, format: ExportFormat): string {
  return `/tmp/${slugify(title)}.${extensionFor(format)}`;
}

function withExtension(path: string, format: ExportFormat): string {
  const parts = path.split("/");
  const last = parts.pop() || "conversation";
  const base = last.includes(".") ? last.slice(0, last.lastIndexOf(".")) : last;
  const next = `${base || "conversation"}.${extensionFor(format)}`;
  return [...parts, next].join("/");
}

function passphraseStrength(passphrase: string): string {
  if (passphrase.length < 8) {
    return "Weak";
  }

  let score = 0;
  if (/[A-Z]/.test(passphrase)) {
    score += 1;
  }
  if (/[a-z]/.test(passphrase)) {
    score += 1;
  }
  if (/[0-9]/.test(passphrase)) {
    score += 1;
  }
  if (/[^A-Za-z0-9]/.test(passphrase)) {
    score += 1;
  }
  if (passphrase.length >= 14) {
    score += 1;
  }

  if (score <= 2) {
    return "Fair";
  }
  if (score <= 4) {
    return "Good";
  }
  return "Strong";
}

export default function ExportModal({
  open,
  conversationTitle,
  initialFormat,
  onClose,
  onSubmit,
  submitting,
  error
}: ExportModalProps): JSX.Element | null {
  const [format, setFormat] = useState<ExportFormat>(initialFormat);
  const [destinationPath, setDestinationPath] = useState<string>(
    buildDefaultDestination(conversationTitle, initialFormat)
  );
  const [overwrite, setOverwrite] = useState(false);
  const [includeAttachmentPaths, setIncludeAttachmentPaths] = useState(true);
  const [copyAttachments, setCopyAttachments] = useState(false);
  const [limit, setLimit] = useState<string>("");
  const [encrypt, setEncrypt] = useState(initialFormat === "encrypted_package");
  const [passphrase, setPassphrase] = useState("");
  const [localError, setLocalError] = useState<string | null>(null);

  useEffect(() => {
    if (!open) {
      return;
    }
    setFormat(initialFormat);
    setDestinationPath(buildDefaultDestination(conversationTitle, initialFormat));
    setOverwrite(false);
    setIncludeAttachmentPaths(true);
    setCopyAttachments(false);
    setLimit("");
    setEncrypt(initialFormat === "encrypted_package");
    setPassphrase("");
    setLocalError(null);
  }, [open, initialFormat, conversationTitle]);

  const strength = useMemo(() => passphraseStrength(passphrase), [passphrase]);

  if (!open) {
    return null;
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>): Promise<void> {
    event.preventDefault();
    setLocalError(null);

    if (!destinationPath.startsWith("/")) {
      setLocalError("Destination path must be absolute.");
      return;
    }

    if (encrypt && passphrase.length < 8) {
      setLocalError("Passphrase must be at least 8 characters when encryption is enabled.");
      return;
    }

    await onSubmit({
      format,
      destination_path: destinationPath,
      overwrite,
      include_attachment_paths: includeAttachmentPaths,
      copy_attachments: copyAttachments,
      limit: limit ? Number(limit) : undefined,
      encrypt,
      passphrase: encrypt ? passphrase : undefined
    });
  }

  return (
    <div className="fixed inset-0 z-40 flex items-center justify-center bg-black/35 p-4">
      <form
        onSubmit={handleSubmit}
        className="w-full max-w-2xl rounded-2xl border border-[var(--border-hairline)] bg-[var(--bg-pane)] p-6 shadow-2xl"
      >
        <h2 className="text-lg font-semibold">Export Conversation</h2>
        <p className="mt-1 text-sm text-[var(--text-secondary)]">{conversationTitle}</p>

        <div className="mt-5">
          <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-[var(--text-secondary)]">
            Format
          </p>
          <div className="grid grid-cols-4 gap-2 rounded-xl border border-[var(--border-hairline)] p-1">
            {FORMATS.map((entry) => (
              <button
                key={entry.value}
                type="button"
                onClick={() => {
                  setFormat(entry.value);
                  setDestinationPath((current) => withExtension(current, entry.value));
                  if (entry.value === "encrypted_package") {
                    setEncrypt(true);
                  }
                }}
                className={`rounded-lg px-3 py-2 text-sm ${
                  format === entry.value
                    ? "bg-[var(--accent)] text-white"
                    : "text-[var(--text-secondary)] hover:bg-black/5 dark:hover:bg-white/5"
                }`}
              >
                {entry.label}
              </button>
            ))}
          </div>
        </div>

        <div className="mt-4 space-y-2">
          <label className="text-xs font-semibold uppercase tracking-wide text-[var(--text-secondary)]">
            Destination
          </label>
          <div className="flex gap-2">
            <input
              value={destinationPath}
              onChange={(event) => setDestinationPath(event.target.value)}
              className="h-10 flex-1 rounded-lg border border-[var(--border-hairline)] bg-transparent px-3 text-sm outline-none ring-[var(--accent)] focus:ring-1"
            />
            <button
              type="button"
              onClick={() => setDestinationPath(buildDefaultDestination(conversationTitle, format))}
              className="h-10 rounded-lg border border-[var(--border-hairline)] px-3 text-sm"
            >
              Use Default
            </button>
          </div>
        </div>

        <div className="mt-4 grid grid-cols-2 gap-3 text-sm">
          <label className="flex items-center gap-2">
            <input type="checkbox" checked={includeAttachmentPaths} onChange={(e) => setIncludeAttachmentPaths(e.target.checked)} />
            include_attachment_paths
          </label>
          <label className="flex items-center gap-2">
            <input type="checkbox" checked={copyAttachments} onChange={(e) => setCopyAttachments(e.target.checked)} />
            copy_attachments
          </label>
          <label className="flex items-center gap-2">
            <input type="checkbox" checked={overwrite} onChange={(e) => setOverwrite(e.target.checked)} />
            overwrite
          </label>
          <label className="flex items-center gap-2">
            <input
              type="checkbox"
              checked={encrypt}
              onChange={(e) => setEncrypt(e.target.checked)}
              disabled={format === "encrypted_package"}
            />
            encrypt
          </label>
        </div>

        <div className="mt-4 grid grid-cols-[auto_1fr] items-center gap-3 text-sm">
          <label htmlFor="limit-input" className="text-[var(--text-secondary)]">
            limit messages
          </label>
          <input
            id="limit-input"
            type="number"
            min={1}
            step={1}
            value={limit}
            onChange={(event) => setLimit(event.target.value)}
            placeholder="All"
            className="h-9 rounded-lg border border-[var(--border-hairline)] bg-transparent px-3 outline-none ring-[var(--accent)] focus:ring-1"
          />
        </div>

        {encrypt ? (
          <div className="mt-4 space-y-2 rounded-lg border border-[var(--border-hairline)] bg-black/5 p-3 dark:bg-white/5">
            <label className="block text-sm">
              Passphrase
              <input
                type="password"
                value={passphrase}
                onChange={(event) => setPassphrase(event.target.value)}
                className="mt-1 h-9 w-full rounded-lg border border-[var(--border-hairline)] bg-transparent px-3 outline-none ring-[var(--accent)] focus:ring-1"
              />
            </label>
            <p className="text-xs text-[var(--text-secondary)]">Strength hint: {strength}</p>
          </div>
        ) : null}

        {localError || error ? (
          <p className="mt-4 rounded-lg border border-red-500/40 bg-red-500/10 px-3 py-2 text-sm text-red-600 dark:text-red-300">
            {localError ?? error}
          </p>
        ) : null}

        <div className="mt-6 flex justify-end gap-2">
          <button
            type="button"
            onClick={onClose}
            className="rounded-lg border border-[var(--border-hairline)] px-3 py-2 text-sm"
          >
            Cancel
          </button>
          <button
            type="submit"
            disabled={submitting}
            className="rounded-lg bg-[var(--accent)] px-3 py-2 text-sm font-medium text-white disabled:opacity-60"
          >
            {submitting ? "Exporting..." : "Export"}
          </button>
        </div>
      </form>
    </div>
  );
}
