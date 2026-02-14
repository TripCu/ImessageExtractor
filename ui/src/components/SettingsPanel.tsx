interface SettingsPanelProps {
  open: boolean;
  singleClickExport: boolean;
  onSingleClickExportChange: (value: boolean) => void;
  onClose: () => void;
}

export default function SettingsPanel({
  open,
  singleClickExport,
  onSingleClickExportChange,
  onClose
}: SettingsPanelProps): JSX.Element | null {
  if (!open) {
    return null;
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/25 p-4">
      <div className="w-full max-w-md rounded-xl border border-[var(--border-hairline)] bg-[var(--bg-pane)] p-6 shadow-xl">
        <h2 className="text-lg font-semibold">Settings</h2>
        <label className="mt-4 flex cursor-pointer items-center justify-between gap-4 text-sm">
          <span>Enable single-click export</span>
          <input
            type="checkbox"
            checked={singleClickExport}
            onChange={(event) => onSingleClickExportChange(event.target.checked)}
          />
        </label>
        <div className="mt-6 flex justify-end">
          <button
            type="button"
            onClick={onClose}
            className="rounded-lg border border-[var(--border-hairline)] px-3 py-1.5 text-sm"
          >
            Done
          </button>
        </div>
      </div>
    </div>
  );
}
