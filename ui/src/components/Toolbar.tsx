interface ToolbarProps {
  search: string;
  onSearchChange: (value: string) => void;
  onExportClick: () => void;
  onSettingsClick: () => void;
  showExportButton: boolean;
}

function TrafficLights(): JSX.Element {
  return (
    <div className="flex items-center gap-2 pr-4" aria-hidden>
      <span className="h-3 w-3 rounded-full bg-[#ff5f57]" />
      <span className="h-3 w-3 rounded-full bg-[#febc2e]" />
      <span className="h-3 w-3 rounded-full bg-[#28c840]" />
    </div>
  );
}

export default function Toolbar({
  search,
  onSearchChange,
  onExportClick,
  onSettingsClick,
  showExportButton
}: ToolbarProps): JSX.Element {
  return (
    <header className="top-toolbar flex items-center px-3">
      <TrafficLights />
      <div className="mx-auto flex max-w-4xl flex-1 items-center gap-3">
        <label className="relative flex-1">
          <span className="sr-only">Search conversations</span>
          <input
            value={search}
            onChange={(event) => onSearchChange(event.target.value)}
            placeholder="Search"
            className="h-8 w-full rounded-[10px] border border-[var(--border-hairline)] bg-white/60 px-3 text-sm text-[var(--text-primary)] outline-none ring-[var(--accent)] focus:ring-1 dark:bg-black/20"
          />
        </label>
        {showExportButton ? (
          <button
            type="button"
            onClick={onExportClick}
            className="h-8 rounded-[9px] border border-[var(--border-hairline)] px-3 text-sm font-medium"
          >
            Export
          </button>
        ) : null}
        <button
          type="button"
          onClick={onSettingsClick}
          className="h-8 rounded-[9px] border border-[var(--border-hairline)] px-3 text-sm"
        >
          Settings
        </button>
      </div>
    </header>
  );
}
