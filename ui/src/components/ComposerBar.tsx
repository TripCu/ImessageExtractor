export default function ComposerBar(): JSX.Element {
  return (
    <div className="pane-composer">
      <button
        type="button"
        disabled
        title="Composer is disabled. This app is export-only."
        className="h-9 w-full cursor-not-allowed rounded-full border border-[var(--border-hairline)] bg-black/5 px-4 text-left text-sm text-[var(--text-secondary)] dark:bg-white/5"
      >
        Message (disabled in export mode)
      </button>
    </div>
  );
}
