import { useMemo, useState } from "react";
import type { ConversationPreview } from "./api";
import Toolbar from "./components/Toolbar";
import Sidebar from "./components/Sidebar";
import FakeChatPane from "./components/FakeChatPane";
import ComposerBar from "./components/ComposerBar";
import ExportModal from "./components/ExportModal";
import SettingsPanel from "./components/SettingsPanel";

const MOCK_CONVERSATIONS: ConversationPreview[] = [
  {
    id: "1",
    title: "Alex Parker",
    snippet: "Draft placeholders only",
    timestamp: "9:41",
    unread: false
  },
  {
    id: "2",
    title: "Product Team",
    snippet: "No real messages displayed",
    timestamp: "Yesterday",
    unread: true
  },
  {
    id: "3",
    title: "Mom",
    snippet: "Export-ready conversation",
    timestamp: "Thu",
    unread: false
  },
  {
    id: "4",
    title: "Jordan",
    snippet: "Click to export",
    timestamp: "Wed",
    unread: false
  }
];

export default function App(): JSX.Element {
  const [search, setSearch] = useState("");
  const [selectedId, setSelectedId] = useState<string | null>(MOCK_CONVERSATIONS[0].id);
  const [showExportModal, setShowExportModal] = useState(false);
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [singleClickExport, setSingleClickExport] = useState(true);

  const conversations = useMemo(() => {
    const lowered = search.trim().toLowerCase();
    if (!lowered) {
      return MOCK_CONVERSATIONS;
    }
    return MOCK_CONVERSATIONS.filter((conversation) => {
      return (
        conversation.title.toLowerCase().includes(lowered) ||
        conversation.snippet.toLowerCase().includes(lowered)
      );
    });
  }, [search]);

  const selectedConversation = conversations.find((conversation) => conversation.id === selectedId) ?? null;

  const handleSelectConversation = (conversationId: string): void => {
    setSelectedId(conversationId);
    if (singleClickExport) {
      setShowExportModal(true);
    }
  };

  return (
    <>
      <div className="app-shell">
        <Toolbar
          search={search}
          onSearchChange={setSearch}
          onExportClick={() => setShowExportModal(true)}
          onSettingsClick={() => setSettingsOpen(true)}
          showExportButton={!singleClickExport}
        />
        <div className="split-view">
          <Sidebar
            conversations={conversations}
            selectedId={selectedId}
            onSelect={handleSelectConversation}
          />
          <section className="chat-pane">
            <header className="pane-header">
              <div>
                <h1 className="m-0 text-[15px] font-semibold">{selectedConversation?.title ?? "Conversation"}</h1>
                <p className="m-0 text-xs text-[var(--text-secondary)]">Export-first mode</p>
              </div>
            </header>
            <main className="pane-content">
              <FakeChatPane />
            </main>
            <ComposerBar />
          </section>
        </div>
      </div>

      <ExportModal
        open={showExportModal}
        conversationTitle={selectedConversation?.title ?? ""}
        onClose={() => setShowExportModal(false)}
      />

      <SettingsPanel
        open={settingsOpen}
        singleClickExport={singleClickExport}
        onSingleClickExportChange={setSingleClickExport}
        onClose={() => setSettingsOpen(false)}
      />
    </>
  );
}
