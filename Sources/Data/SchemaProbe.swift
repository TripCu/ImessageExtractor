import Foundation

struct SchemaProbe {
    static let requiredChat = ["ROWID", "guid"]
    static let requiredMessage = ["ROWID", "date", "is_from_me"]

    static func probe(db: SQLiteReadOnly) throws -> SchemaProbeResult {
        let chat = try fetchColumns(db: db, table: "chat")
        let message = try fetchColumns(db: db, table: "message")
        let handle = try fetchColumns(db: db, table: "handle")

        var missing: [String] = []
        for col in requiredChat where !chat.contains(col) { missing.append("chat.\(col)") }
        for col in requiredMessage where !message.contains(col) { missing.append("message.\(col)") }

        return SchemaProbeResult(
            chatColumns: chat,
            messageColumns: message,
            handleColumns: handle,
            requiredMissing: missing
        )
    }

    private static func fetchColumns(db: SQLiteReadOnly, table: String) throws -> Set<String> {
        let rows = try db.queryRows(sql: "PRAGMA table_info(\(table));")
        return Set(rows.compactMap { $0["name"]?.string })
    }
}
