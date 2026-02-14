import type { ConversationPreview } from "../api";
import type { MouseEvent } from "react";

interface ConversationRowProps {
  conversation: ConversationPreview;
  selected: boolean;
  onSelect: (id: string) => void;
  onContextMenu: (id: string, event: MouseEvent<HTMLButtonElement>) => void;
}

export default function ConversationRow({
  conversation,
  selected,
  onSelect,
  onContextMenu
}: ConversationRowProps): JSX.Element {
  return (
    <button
      type="button"
      onClick={() => onSelect(conversation.id)}
      onContextMenu={(event) => onContextMenu(conversation.id, event)}
      className={`w-full rounded-[var(--radius-selection)] px-3 py-2 text-left transition-colors ${
        selected ? "bg-[var(--bg-selected)]" : "hover:bg-black/5 dark:hover:bg-white/5"
      }`}
    >
      <div className="flex items-baseline justify-between gap-2">
        <span className="truncate text-sm font-semibold">{conversation.title}</span>
        <span className="shrink-0 text-xs text-[var(--text-secondary)]">{conversation.timestamp}</span>
      </div>
      <div className="mt-1 flex items-center gap-2">
        {conversation.unread ? <span className="h-2 w-2 rounded-full bg-[var(--accent)]" /> : null}
        <span className="truncate text-xs text-[var(--text-secondary)]">{conversation.snippet}</span>
      </div>
    </button>
  );
}
