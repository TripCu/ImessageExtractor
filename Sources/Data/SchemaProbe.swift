import Foundation

struct SchemaProbe {
    static let requiredChat = ["ROWID", "guid"]
    static let requiredMessage = ["ROWID", "date", "is_from_me"]
    static let requiredTables = ["chat", "message", "chat_message_join"]

    static func probe(db: SQLiteReadOnly) throws -> SchemaProbeResult {
        let tables = try fetchTables(db: db)
        var missing: [String] = []
        for table in requiredTables where !tables.contains(table) {
            missing.append("table.\(table)")
        }

        let chat = try fetchColumns(db: db, table: "chat")
        let message = try fetchColumns(db: db, table: "message")
        let handle = try fetchColumns(db: db, table: "handle")
        let chatHandleJoin = try fetchColumns(db: db, table: "chat_handle_join")
        let chatMessageJoin = try fetchColumns(db: db, table: "chat_message_join")
        let messageAttachmentJoin = try fetchColumns(db: db, table: "message_attachment_join")
        let attachment = try fetchColumns(db: db, table: "attachment")

        for col in requiredChat where !chat.contains(col) { missing.append("chat.\(col)") }
        for col in requiredMessage where !message.contains(col) { missing.append("message.\(col)") }

        return SchemaProbeResult(
            tables: tables,
            chatColumns: chat,
            messageColumns: message,
            handleColumns: handle,
            chatHandleJoinColumns: chatHandleJoin,
            chatMessageJoinColumns: chatMessageJoin,
            messageAttachmentJoinColumns: messageAttachmentJoin,
            attachmentColumns: attachment,
            requiredMissing: missing
        )
    }

    private static func fetchTables(db: SQLiteReadOnly) throws -> Set<String> {
        let rows = try db.queryRows(sql: "SELECT name FROM sqlite_master WHERE type='table';")
        return Set(rows.compactMap { $0["name"]?.string })
    }

    private static func fetchColumns(db: SQLiteReadOnly, table: String) throws -> Set<String> {
        let tableName = table.replacingOccurrences(of: "'", with: "''")
        let tables = try fetchTables(db: db)
        guard tables.contains(tableName) else { return [] }
        let rows = try db.queryRows(sql: "PRAGMA table_info(\(table));")
        return Set(rows.compactMap { $0["name"]?.string })
    }
}
