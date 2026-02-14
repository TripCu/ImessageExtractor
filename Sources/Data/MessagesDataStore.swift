import Foundation

struct ConversationPageResult: Sendable {
    let dbPath: String
    let probe: SchemaProbeResult
    let conversations: [ConversationSummary]
    let totalChats: Int
    let totalMessages: Int
}

enum DataStoreQueryError: Error {
    case unsupportedSchema(missing: [String])
}

@MainActor
final class MessagesDataStore: ObservableObject {
    @Published var conversations: [ConversationSummary] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var canLoadMore = true

    private var offset = 0
    private let pageSize = 100
    private var inFlightLoad: Task<ConversationPageResult, Error>?
    private let diagnostics: DiagnosticsStore

    #if DEBUG
    @Published var useSyntheticDB = false
    #endif

    init(diagnostics: DiagnosticsStore) {
        self.diagnostics = diagnostics
    }

    func resetAndLoad() async {
        inFlightLoad?.cancel()
        offset = 0
        conversations = []
        canLoadMore = true
        await loadMore()
    }

    func loadMore() async {
        guard !isLoading, canLoadMore else { return }
        isLoading = true
        defer { isLoading = false }

        let startOffset = offset
        let synthetic = currentUseSynthetic
        let limit = pageSize
        inFlightLoad?.cancel()

        let task = Task.detached(priority: .userInitiated) {
            try Self.fetchConversationPage(offset: startOffset, limit: limit, useSynthetic: synthetic)
        }
        inFlightLoad = task

        do {
            let page = try await task.value
            diagnostics.updateFileAccess(path: page.dbPath, opened: true)
            diagnostics.updateSchema(page.probe)
            diagnostics.updateCounts(chats: page.totalChats, messages: page.totalMessages)
            diagnostics.clearLastError()

            if startOffset == 0 {
                conversations = page.conversations
            } else {
                conversations += page.conversations
            }

            offset = startOffset + page.conversations.count
            canLoadMore = offset < page.totalChats && !page.conversations.isEmpty
            errorMessage = nil
            AppLogger.info("DB", "Loaded conversations page offset=\(startOffset) count=\(page.conversations.count)")
        } catch is CancellationError {
            AppLogger.debug("DB", "Conversation load cancelled")
        } catch let error as DataStoreQueryError {
            switch error {
            case let .unsupportedSchema(missing):
                diagnostics.setLastError(.schemaMismatch)
                errorMessage = "Unsupported Messages DB schema on this macOS version. Missing: \(missing.joined(separator: ", "))"
            }
            AppLogger.error("Schema", errorMessage ?? "Unsupported schema")
        } catch DBError.fileMissing {
            diagnostics.updateFileAccess(path: Self.resolveDBPath(useSynthetic: false), opened: false)
            diagnostics.setLastError(.missingFile)
            errorMessage = "Cannot find ~/Library/Messages/chat.db"
            AppLogger.error("DB", "Messages DB file missing")
        } catch DBError.openFailed {
            diagnostics.updateFileAccess(path: Self.resolveDBPath(useSynthetic: false), opened: false)
            diagnostics.setLastError(.permission)
            errorMessage = "Full Disk Access likely missing. Open Diagnostics for exact steps."
            AppLogger.error("DB", "Failed to open Messages DB")
        } catch {
            diagnostics.setLastError(.unknown)
            errorMessage = "Unexpected database error: \(error.localizedDescription)"
            AppLogger.error("DB", error.localizedDescription)
        }
    }

    func messages(for conversation: ConversationSummary) async -> [MessageItem] {
        let synthetic = currentUseSynthetic
        do {
            return try await Task.detached(priority: .userInitiated) {
                try Self.fetchMessages(for: conversation, useSynthetic: synthetic)
            }.value
        } catch let error as DataStoreQueryError {
            switch error {
            case .unsupportedSchema:
                diagnostics.setLastError(.schemaMismatch)
                errorMessage = "Unsupported schema for message export. Open Diagnostics."
            }
            return []
        } catch {
            diagnostics.setLastError(.unknown)
            errorMessage = "Failed to load messages for export."
            return []
        }
    }

    nonisolated private static func fetchConversationPage(offset: Int, limit: Int, useSynthetic: Bool) throws -> ConversationPageResult {
        let dbPath = resolveDBPath(useSynthetic: useSynthetic)
        let db = try SQLiteReadOnly(path: dbPath)
        let probe = try SchemaProbe.probe(db: db)
        guard probe.isSupported else {
            throw DataStoreQueryError.unsupportedSchema(missing: probe.requiredMissing)
        }

        let query = QueryBuilder.conversationQuery(probe: probe, offset: offset, limit: limit)
        let rows = try db.queryRows(sql: query)

        var items: [ConversationSummary] = []
        items.reserveCapacity(rows.count)
        for row in rows {
            let rowID = row["rowid"]?.int64
            let id = row["id"]?.string ?? "rowid-\(rowID ?? 0)"
            let participants = try fetchParticipants(db: db, probe: probe, chatRowID: rowID)
            let title = deriveTitle(rawTitle: row["display_name"]?.string, participants: participants)
            let preview = row["preview"]?.string?.trimmingCharacters(in: .whitespacesAndNewlines)
            let isGroup = (row["is_group"]?.int64 ?? 0) > 0

            items.append(
                ConversationSummary(
                    id: id,
                    sourceRowID: rowID,
                    title: title,
                    participantHandles: participants,
                    participantDisplayNames: participants,
                    lastPreview: (preview?.isEmpty == false ? preview : nil),
                    lastDate: AppleDateConverter.convert(raw: row["last_date"]?.int64),
                    isGroup: isGroup
                )
            )
        }

        let chatCount = Int((try db.queryRows(sql: "SELECT COUNT(*) AS c FROM chat;").first?["c"]?.int64) ?? Int64(items.count))
        let messageCount = Int((try db.queryRows(sql: "SELECT COUNT(*) AS c FROM message;").first?["c"]?.int64) ?? 0)

        return ConversationPageResult(
            dbPath: dbPath,
            probe: probe,
            conversations: items,
            totalChats: chatCount,
            totalMessages: messageCount
        )
    }

    nonisolated private static func fetchParticipants(db: SQLiteReadOnly, probe: SchemaProbeResult, chatRowID: Int64?) throws -> [String] {
        guard let chatRowID else { return [] }
        guard probe.tables.contains("chat_handle_join"), probe.tables.contains("handle") else { return [] }
        guard probe.chatHandleJoinColumns.contains("chat_id"), probe.chatHandleJoinColumns.contains("handle_id") else { return [] }
        guard probe.handleColumns.contains("id") else { return [] }

        let rows = try db.queryRows(sql: """
        SELECT DISTINCT h.id AS handle
        FROM chat_handle_join chj
        JOIN handle h ON h.ROWID = chj.handle_id
        WHERE chj.chat_id = \(chatRowID)
        ORDER BY h.id ASC;
        """)

        var handles: [String] = []
        handles.reserveCapacity(rows.count)
        for row in rows {
            if let handle = row["handle"]?.string, !handle.isEmpty {
                handles.append(handle)
            }
        }
        return handles
    }

    nonisolated private static func deriveTitle(rawTitle: String?, participants: [String]) -> String {
        if let rawTitle, !rawTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return rawTitle
        }
        if participants.isEmpty { return "Conversation" }
        if participants.count == 1 { return participants[0] }
        return participants.prefix(3).joined(separator: ", ")
    }

    nonisolated private static func fetchMessages(for conversation: ConversationSummary, useSynthetic: Bool) throws -> [MessageItem] {
        let db = try SQLiteReadOnly(path: resolveDBPath(useSynthetic: useSynthetic))
        let probe = try SchemaProbe.probe(db: db)
        guard probe.isSupported else {
            throw DataStoreQueryError.unsupportedSchema(missing: probe.requiredMissing)
        }

        let whereClause: String
        if let rowID = conversation.sourceRowID {
            whereClause = "c.ROWID = \(rowID)"
        } else {
            let escaped = conversation.id.replacingOccurrences(of: "'", with: "''")
            whereClause = "c.guid = '\(escaped)' OR CAST(c.ROWID AS TEXT) = '\(escaped)'"
        }

        let senderSelect = (probe.messageColumns.contains("handle_id") && probe.tables.contains("handle") && probe.handleColumns.contains("id")) ? "h.id" : "NULL"
        let senderJoin = (probe.messageColumns.contains("handle_id") && probe.tables.contains("handle") && probe.handleColumns.contains("id")) ? "LEFT JOIN handle h ON h.ROWID = m.handle_id" : ""
        let attributedSelect = probe.messageColumns.contains("attributedBody") ? "m.attributedBody" : "NULL"

        let rows = try db.queryRows(sql: """
        SELECT
          COALESCE(m.guid, CAST(m.ROWID AS TEXT)) AS id,
          m.ROWID AS message_rowid,
          m.date AS date,
          m.is_from_me AS is_from_me,
          m.text AS text,
          \(attributedSelect) AS attributed_body,
          \(senderSelect) AS sender
        FROM message m
        JOIN chat_message_join cmj ON cmj.message_id = m.ROWID
        JOIN chat c ON c.ROWID = cmj.chat_id
        \(senderJoin)
        WHERE \(whereClause)
        ORDER BY m.date ASC
        LIMIT 10000;
        """)

        var result: [MessageItem] = []
        result.reserveCapacity(rows.count)
        for row in rows {
            let messageRowID = row["message_rowid"]?.int64
            let attachments = try fetchAttachments(db: db, probe: probe, messageRowID: messageRowID)
            let attributed: String?
            switch row["attributed_body"] {
            case let .blob(data): attributed = data.base64EncodedString()
            default: attributed = nil
            }

            result.append(MessageItem(
                id: row["id"]?.string ?? UUID().uuidString,
                conversationId: conversation.id,
                date: AppleDateConverter.convert(raw: row["date"]?.int64) ?? Date.distantPast,
                sender: row["sender"]?.string,
                isFromMe: (row["is_from_me"]?.int64 ?? 0) > 0,
                text: row["text"]?.string,
                attributedBodyBase64: attributed,
                attachments: attachments
            ))
        }
        return result
    }

    nonisolated private static func fetchAttachments(db: SQLiteReadOnly, probe: SchemaProbeResult, messageRowID: Int64?) throws -> [AttachmentMetadata] {
        guard let messageRowID else { return [] }
        guard probe.tables.contains("message_attachment_join"), probe.tables.contains("attachment") else { return [] }
        guard probe.messageAttachmentJoinColumns.contains("message_id"), probe.messageAttachmentJoinColumns.contains("attachment_id") else { return [] }

        let fileColumn = probe.attachmentColumns.contains("filename") ? "a.filename" : "NULL"
        let mimeColumn = probe.attachmentColumns.contains("mime_type") ? "a.mime_type" : "NULL"
        let transferColumn = probe.attachmentColumns.contains("transfer_name") ? "a.transfer_name" : "NULL"

        let rows = try db.queryRows(sql: """
        SELECT \(fileColumn) AS filename, \(mimeColumn) AS mime_type, \(transferColumn) AS transfer_name
        FROM message_attachment_join maj
        JOIN attachment a ON a.ROWID = maj.attachment_id
        WHERE maj.message_id = \(messageRowID);
        """)

        return rows.map { row in
            AttachmentMetadata(
                filename: row["filename"]?.string,
                mimeType: row["mime_type"]?.string,
                transferName: row["transfer_name"]?.string
            )
        }
    }

    nonisolated static func resolveDBPath(useSynthetic: Bool) -> String {
        #if DEBUG
        if useSynthetic {
            if let explicit = ProcessInfo.processInfo.environment["SYNTHETIC_DB_PATH"], !explicit.isEmpty { return explicit }
            let cwd = FileManager.default.currentDirectoryPath
            let local = cwd + "/Resources/synthetic-chat.db"
            if FileManager.default.fileExists(atPath: local) { return local }
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
        let displayColumn = probe.chatColumns.contains("display_name") ? "COALESCE(c.display_name, '')" : "''"
        let guidColumn = probe.chatColumns.contains("guid") ? "COALESCE(c.guid, CAST(c.ROWID AS TEXT))" : "CAST(c.ROWID AS TEXT)"
        let lastDateColumn = probe.messageColumns.contains("date") ? "MAX(m.date)" : "0"

        let previewColumn: String
        if probe.messageColumns.contains("text") {
            previewColumn = "MAX(COALESCE(m.text, ''))"
        } else if probe.messageColumns.contains("attributedBody") {
            previewColumn = "MAX(CASE WHEN m.attributedBody IS NULL THEN '' ELSE '[Attributed Message]' END)"
        } else {
            previewColumn = "''"
        }

        let groupExpr: String
        let groupJoin: String
        if probe.chatColumns.contains("style") {
            groupExpr = "CASE WHEN c.style = 45 THEN 1 ELSE 0 END"
            groupJoin = ""
        } else if probe.tables.contains("chat_handle_join") && probe.chatHandleJoinColumns.contains("chat_id") && probe.chatHandleJoinColumns.contains("handle_id") {
            groupExpr = "CASE WHEN COUNT(DISTINCT chj.handle_id) > 1 THEN 1 ELSE 0 END"
            groupJoin = "LEFT JOIN chat_handle_join chj ON chj.chat_id = c.ROWID"
        } else {
            groupExpr = "0"
            groupJoin = ""
        }

        return """
        SELECT
            \(guidColumn) AS id,
            c.ROWID AS rowid,
            \(displayColumn) AS display_name,
            \(previewColumn) AS preview,
            \(lastDateColumn) AS last_date,
            \(groupExpr) AS is_group
        FROM chat c
        LEFT JOIN chat_message_join cmj ON cmj.chat_id = c.ROWID
        LEFT JOIN message m ON m.ROWID = cmj.message_id
        \(groupJoin)
        GROUP BY c.ROWID
        ORDER BY last_date DESC
        LIMIT \(limit) OFFSET \(offset);
        """
    }
}
