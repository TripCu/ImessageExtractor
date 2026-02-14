interface StatusPaneProps {
  title: string;
  subtitle: string;
}

export default function StatusPane({ title, subtitle }: StatusPaneProps): JSX.Element {
  return (
    <div className="flex h-full flex-col items-center justify-center gap-2 text-center">
      <h2 className="text-xl font-semibold">{title}</h2>
      <p className="max-w-sm text-sm text-[var(--text-secondary)]">{subtitle}</p>
    </div>
  );
}
