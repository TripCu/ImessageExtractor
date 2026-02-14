import Foundation
import OSLog

@MainActor
final class MessagesDataStore: ObservableObject {
    @Published var conversations: [ConversationSummary] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var canLoadMore = true

    private var offset = 0
    private let pageSize = 100
    private let diagnostics: DiagnosticsStore

    #if DEBUG
    @Published var useSyntheticDB = false
    #endif

    init(diagnostics: DiagnosticsStore) {
        self.diagnostics = diagnostics
    }

    func resetAndLoad() async {
        offset = 0
        conversations = []
        canLoadMore = true
        await loadMore()
    }

    func loadMore() async {
        guard !isLoading, canLoadMore else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let dbPath = Self.resolveDBPath(useSynthetic: currentUseSynthetic)
            let db = try SQLiteReadOnly(path: dbPath)
            diagnostics.updateFileAccess(path: dbPath, opened: true)

            let probe = try SchemaProbe.probe(db: db)
            diagnostics.updateSchema(probe)
            if !probe.isSupported {
                diagnostics.setLastError(.schemaMismatch)
                errorMessage = "Unsupported Messages DB schema on this macOS version. Open Diagnostics for details."
                return
            }

            let query = QueryBuilder.conversationQuery(probe: probe, offset: offset, limit: pageSize)
            let rows = try db.queryRows(sql: query)
            var page: [ConversationSummary] = []
            page.reserveCapacity(rows.count)
            for row in rows {
                let id = row["id"]?.string ?? "rowid-\(row["rowid"]?.int64 ?? 0)"
                let title = row["display_name"]?.string ?? "Conversation"
                let preview = row["preview"]?.string
                let lastDate = AppleDateConverter.convert(raw: row["last_date"]?.int64)
                let isGroup = (row["is_group"]?.int64 ?? 0) > 0
                page.append(ConversationSummary(id: id, title: title, participantHandles: [], lastPreview: preview, lastDate: lastDate, isGroup: isGroup))
            }

            conversations += page
            offset += page.count
            canLoadMore = page.count == pageSize

            let countRows = try db.queryRows(sql: "SELECT COUNT(*) AS c FROM message;")
            diagnostics.updateCounts(chats: conversations.count, messages: Int(countRows.first?["c"]?.int64 ?? 0))
            errorMessage = nil
        } catch DBError.fileMissing {
            diagnostics.updateFileAccess(path: Self.resolveDBPath(useSynthetic: false), opened: false)
            diagnostics.setLastError(.missingFile)
            errorMessage = "Cannot find ~/Library/Messages/chat.db"
        } catch DBError.openFailed {
            diagnostics.updateFileAccess(path: Self.resolveDBPath(useSynthetic: false), opened: false)
            diagnostics.setLastError(.permission)
            errorMessage = "Full Disk Access likely missing. Open Diagnostics for exact steps."
        } catch {
            diagnostics.setLastError(.unknown)
            errorMessage = error.localizedDescription
        }
    }

    func messages(for conversation: ConversationSummary) async -> [MessageItem] {
        do {
            let db = try SQLiteReadOnly(path: Self.resolveDBPath(useSynthetic: currentUseSynthetic))
            let escaped = conversation.id.replacingOccurrences(of: "'", with: "''")
            let rows = try db.queryRows(sql: """
            SELECT
              COALESCE(m.guid, CAST(m.ROWID AS TEXT)) AS id,
              m.date AS date,
              m.is_from_me AS is_from_me,
              m.text AS text
            FROM message m
            JOIN chat_message_join cmj ON cmj.message_id = m.ROWID
            JOIN chat c ON c.ROWID = cmj.chat_id
            WHERE c.guid = '\(escaped)' OR CAST(c.ROWID AS TEXT) = '\(escaped)'
            ORDER BY m.date ASC
            LIMIT 5000;
            """)
            var result: [MessageItem] = []
            result.reserveCapacity(rows.count)
            for row in rows {
                result.append(MessageItem(
                    id: row["id"]?.string ?? UUID().uuidString,
                    conversationId: conversation.id,
                    date: AppleDateConverter.convert(raw: row["date"]?.int64) ?? Date.distantPast,
                    sender: nil,
                    isFromMe: (row["is_from_me"]?.int64 ?? 0) > 0,
                    text: row["text"]?.string
                ))
            }
            return result
        } catch {
            diagnostics.setLastError(.unknown)
            return []
        }
    }

    static func resolveDBPath(useSynthetic: Bool) -> String {
        #if DEBUG
        if useSynthetic {
            if let explicit = ProcessInfo.processInfo.environment["SYNTHETIC_DB_PATH"], !explicit.isEmpty { return explicit }
            let cwd = FileManager.default.currentDirectoryPath
            let local = cwd + "/Resources/synthetic-chat.db"
            if FileManager.default.fileExists(atPath: local) { return local }
            let repo = cwd + "/macos-app/Resources/synthetic-chat.db"
            if FileManager.default.fileExists(atPath: repo) { return repo }
        }
        #endif
        return NSHomeDirectory() + "/Library/Messages/chat.db"
    }

    private var currentUseSynthetic: Bool {
        #if DEBUG
        return useSyntheticDB
        #else
        return false
        #endif
    }
}

enum QueryBuilder {
    static func conversationQuery(probe: SchemaProbeResult, offset: Int, limit: Int) -> String {
        let displayColumn = probe.chatColumns.contains("display_name") ? "COALESCE(c.display_name, 'Conversation')" : "'Conversation'"
        let guidColumn = probe.chatColumns.contains("guid") ? "c.guid" : "CAST(c.ROWID AS TEXT)"
        let lastDateColumn = probe.messageColumns.contains("date") ? "MAX(m.date)" : "NULL"
        let previewColumn = probe.messageColumns.contains("text") ? "MAX(COALESCE(m.text, ''))" : "''"
        return """
        SELECT
            \(guidColumn) AS id,
            c.ROWID AS rowid,
            \(displayColumn) AS display_name,
            \(previewColumn) AS preview,
            \(lastDateColumn) AS last_date,
            CASE WHEN c.style = 45 THEN 1 ELSE 0 END AS is_group
        FROM chat c
        LEFT JOIN chat_message_join cmj ON cmj.chat_id = c.ROWID
        LEFT JOIN message m ON m.ROWID = cmj.message_id
        GROUP BY c.ROWID
        ORDER BY last_date DESC
        LIMIT \(limit) OFFSET \(offset);
        """
    }
}
