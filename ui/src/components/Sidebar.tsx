import type { ConversationPreview } from "../api";
import ConversationRow from "./ConversationRow";

interface SidebarProps {
  conversations: ConversationPreview[];
  selectedId: string | null;
  onSelect: (id: string) => void;
}

export default function Sidebar({
  conversations,
  selectedId,
  onSelect
}: SidebarProps): JSX.Element {
  return (
    <aside className="sidebar flex flex-col">
      <div className="flex h-[52px] items-center border-b border-[var(--border-hairline)] px-4 text-sm font-semibold">
        Messages
      </div>
      <div className="flex-1 space-y-1 overflow-y-auto px-2 py-2">
        {conversations.map((conversation) => (
          <ConversationRow
            key={conversation.id}
            conversation={conversation}
            selected={selectedId === conversation.id}
            onSelect={onSelect}
          />
        ))}
      </div>
    </aside>
  );
}
