import { useEffect, useMemo, useState } from "react";
import type { MouseEvent } from "react";

import { exportConversation, listConversations } from "./api";
import type { ConversationPreview, ExportFormat, ExportRequest } from "./api";
import Toolbar from "./components/Toolbar";
import Sidebar from "./components/Sidebar";
import FakeChatPane from "./components/FakeChatPane";
import ComposerBar from "./components/ComposerBar";
import ExportModal from "./components/ExportModal";
import SettingsPanel from "./components/SettingsPanel";
import StatusPane from "./components/StatusPane";

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

interface ContextMenuState {
  x: number;
  y: number;
  conversationId: string;
}

interface ExportStatus {
  title: string;
  subtitle: string;
}

const EXPORT_OPTIONS: Array<{ format: ExportFormat; label: string }> = [
  { format: "text", label: "Export as Text" },
  { format: "json", label: "Export as JSON" },
  { format: "sqlite", label: "Export as SQLite" },
  { format: "encrypted_package", label: "Export as Encrypted Package" }
];

function fallbackBySearch(search: string): ConversationPreview[] {
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
}

export default function App(): JSX.Element {
  const [search, setSearch] = useState("");
  const [conversations, setConversations] = useState<ConversationPreview[]>(MOCK_CONVERSATIONS);
  const [selectedId, setSelectedId] = useState<string | null>(MOCK_CONVERSATIONS[0].id);
  const [showExportModal, setShowExportModal] = useState(false);
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [singleClickExport, setSingleClickExport] = useState(true);
  const [contextMenu, setContextMenu] = useState<ContextMenuState | null>(null);
  const [initialExportFormat, setInitialExportFormat] = useState<ExportFormat>("text");
  const [loadingConversations, setLoadingConversations] = useState(false);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [exportError, setExportError] = useState<string | null>(null);
  const [exporting, setExporting] = useState(false);
  const [exportStatus, setExportStatus] = useState<ExportStatus | null>(null);

  const selectedConversation = useMemo(() => {
    return conversations.find((conversation) => conversation.id === selectedId) ?? null;
  }, [conversations, selectedId]);

  useEffect(() => {
    let active = true;
    const timer = window.setTimeout(async () => {
      setLoadingConversations(true);
      try {
        const remoteConversations = await listConversations(search);
        if (!active) {
          return;
        }
        setConversations(remoteConversations.length > 0 ? remoteConversations : fallbackBySearch(search));
        setLoadError(null);
      } catch {
        if (!active) {
          return;
        }
        setConversations(fallbackBySearch(search));
        setLoadError("Backend unavailable. Showing deterministic placeholders.");
      } finally {
        if (active) {
          setLoadingConversations(false);
        }
      }
    }, 180);

    return () => {
      active = false;
      window.clearTimeout(timer);
    };
  }, [search]);

  useEffect(() => {
    if (!conversations.some((conversation) => conversation.id === selectedId)) {
      setSelectedId(conversations[0]?.id ?? null);
    }
  }, [conversations, selectedId]);

  useEffect(() => {
    const dismissContextMenu = (): void => setContextMenu(null);
    window.addEventListener("click", dismissContextMenu);
    window.addEventListener("resize", dismissContextMenu);
    return () => {
      window.removeEventListener("click", dismissContextMenu);
      window.removeEventListener("resize", dismissContextMenu);
    };
  }, []);

  const openExportModal = (conversationId: string, format: ExportFormat): void => {
    setSelectedId(conversationId);
    setInitialExportFormat(format);
    setExportError(null);
    setShowExportModal(true);
  };

  const handleSelectConversation = (conversationId: string): void => {
    setSelectedId(conversationId);
    setContextMenu(null);
    if (singleClickExport) {
      openExportModal(conversationId, "text");
    }
  };

  const handleContextMenu = (conversationId: string, event: MouseEvent<HTMLButtonElement>): void => {
    event.preventDefault();
    setContextMenu({
      conversationId,
      x: event.clientX,
      y: event.clientY
    });
  };

  const handleExportSubmit = async (payload: ExportRequest): Promise<void> => {
    if (!selectedConversation) {
      setExportError("Select a conversation first.");
      return;
    }

    setExporting(true);
    setExportError(null);

    try {
      const result = await exportConversation(selectedConversation.id, payload);
      setExportStatus({
        title: "Export completed",
        subtitle: `${result.message_count} messages to ${result.output_path}`
      });
      setShowExportModal(false);
    } catch (error) {
      setExportError(error instanceof Error ? error.message : "Export failed");
    } finally {
      setExporting(false);
    }
  };

  return (
    <>
      <div className="app-shell">
        <Toolbar
          search={search}
          onSearchChange={setSearch}
          onExportClick={() => selectedConversation && openExportModal(selectedConversation.id, "text")}
          onSettingsClick={() => setSettingsOpen(true)}
          showExportButton={!singleClickExport}
        />
        <div className="split-view">
          <Sidebar
            conversations={conversations}
            selectedId={selectedId}
            onSelect={handleSelectConversation}
            onContextMenu={handleContextMenu}
          />
          <section className="chat-pane">
            <header className="pane-header">
              <div>
                <h1 className="m-0 text-[15px] font-semibold">{selectedConversation?.title ?? "Conversation"}</h1>
                <p className="m-0 text-xs text-[var(--text-secondary)]">Export-first mode</p>
              </div>
              {loadingConversations ? (
                <p className="m-0 text-xs text-[var(--text-secondary)]">Syncing…</p>
              ) : null}
            </header>
            <main className="pane-content">
              {selectedConversation ? (
                <FakeChatPane seed={selectedConversation.id} showTodaySeparator />
              ) : (
                <StatusPane
                  title="No conversation selected"
                  subtitle="Choose a conversation from the sidebar to configure export options."
                />
              )}
              {loadError ? (
                <p className="mx-4 mt-4 rounded-lg border border-[var(--border-hairline)] bg-black/5 px-3 py-2 text-xs text-[var(--text-secondary)] dark:bg-white/5">
                  {loadError}
                </p>
              ) : null}
              {exportStatus ? (
                <p className="mx-4 mt-2 rounded-lg border border-green-500/30 bg-green-500/10 px-3 py-2 text-xs text-green-700 dark:text-green-300">
                  {exportStatus.title}: {exportStatus.subtitle}
                </p>
              ) : null}
            </main>
            <ComposerBar />
          </section>
        </div>
      </div>

      <ExportModal
        open={showExportModal}
        conversationTitle={selectedConversation?.title ?? "Conversation"}
        initialFormat={initialExportFormat}
        onClose={() => setShowExportModal(false)}
        onSubmit={handleExportSubmit}
        submitting={exporting}
        error={exportError}
      />

      <SettingsPanel
        open={settingsOpen}
        singleClickExport={singleClickExport}
        onSingleClickExportChange={setSingleClickExport}
        onClose={() => setSettingsOpen(false)}
      />

      {contextMenu ? (
        <div
          className="fixed z-50 min-w-64 rounded-xl border border-[var(--border-hairline)] bg-[var(--bg-pane)] p-1 shadow-xl"
          style={{ left: contextMenu.x, top: contextMenu.y }}
          role="menu"
        >
          {EXPORT_OPTIONS.map((option) => (
            <button
              key={option.format}
              type="button"
              className="block w-full rounded-lg px-3 py-2 text-left text-sm hover:bg-black/5 dark:hover:bg-white/5"
              onClick={() => {
                setContextMenu(null);
                openExportModal(contextMenu.conversationId, option.format);
              }}
            >
              {option.label}
            </button>
          ))}
        </div>
      ) : null}
    </>
  );
}
