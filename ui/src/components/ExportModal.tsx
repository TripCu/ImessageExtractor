interface ExportModalProps {
  open: boolean;
  conversationTitle: string;
  onClose: () => void;
}

export default function ExportModal({
  open,
  conversationTitle,
  onClose
}: ExportModalProps): JSX.Element | null {
  if (!open) {
    return null;
  }

  return (
    <div className="fixed inset-0 z-40 flex items-center justify-center bg-black/35 p-4">
      <div className="w-full max-w-xl rounded-2xl border border-[var(--border-hairline)] bg-[var(--bg-pane)] p-6 shadow-2xl">
        <h2 className="text-lg font-semibold">Export Conversation</h2>
        <p className="mt-1 text-sm text-[var(--text-secondary)]">
          {conversationTitle || "No conversation selected"}
        </p>
        <p className="mt-4 text-sm text-[var(--text-secondary)]">
          Export controls are implemented in the export feature module.
        </p>
        <div className="mt-6 flex justify-end">
          <button
            type="button"
            onClick={onClose}
            className="rounded-lg border border-[var(--border-hairline)] px-3 py-1.5 text-sm"
          >
            Close
          </button>
        </div>
      </div>
    </div>
  );
}
