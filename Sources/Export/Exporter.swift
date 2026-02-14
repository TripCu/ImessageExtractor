import Foundation
import SQLite3

struct ExportBundle: Encodable {
    let conversation: ConversationSummary
    let messages: [MessageItem]
}

enum ExportError: Error {
    case invalidDestination
    case writeFailed
}

final class Exporter {
    func exportText(bundle: ExportBundle, to url: URL) throws {
        let lines = bundle.messages.map { msg in
            let ts = ISO8601DateFormatter().string(from: msg.date)
            let sender = msg.isFromMe ? "Me" : (msg.sender ?? "Unknown")
            return "[\(ts)] \(sender): \(msg.text ?? "")"
        }
        try writeSecure(data: lines.joined(separator: "\n").data(using: .utf8) ?? Data(), to: url)
    }

    func exportJSON(bundle: ExportBundle, to url: URL) throws {
        let data = try JSONEncoder.pretty.encode(bundle)
        try writeSecure(data: data, to: url)
    }

    func exportSQLite(bundle: ExportBundle, to url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) { throw ExportError.invalidDestination }
        var db: OpaquePointer?
        guard sqlite3_open(url.path, &db) == SQLITE_OK, let db else { throw ExportError.writeFailed }
        defer { sqlite3_close(db) }

        _ = sqlite3_exec(db, "CREATE TABLE conversation(id TEXT PRIMARY KEY, title TEXT);", nil, nil, nil)
        _ = sqlite3_exec(db, "CREATE TABLE message(id TEXT PRIMARY KEY, conversation_id TEXT, sender TEXT, date REAL, text TEXT, is_from_me INTEGER);", nil, nil, nil)

        _ = sqlite3_exec(db, "BEGIN;", nil, nil, nil)
        _ = sqlite3_exec(db, "INSERT INTO conversation(id,title) VALUES('\(bundle.conversation.id.replacingOccurrences(of: "'", with: "''"))','\(bundle.conversation.title.replacingOccurrences(of: "'", with: "''"))');", nil, nil, nil)
        for m in bundle.messages {
            let text = (m.text ?? "").replacingOccurrences(of: "'", with: "''")
            let sender = (m.sender ?? "").replacingOccurrences(of: "'", with: "''")
            let sql = "INSERT INTO message(id,conversation_id,sender,date,text,is_from_me) VALUES('\(m.id)','\(bundle.conversation.id)','\(sender)',\(m.date.timeIntervalSince1970),'\(text)',\(m.isFromMe ? 1 : 0));"
            _ = sqlite3_exec(db, sql, nil, nil, nil)
        }
        _ = sqlite3_exec(db, "COMMIT;", nil, nil, nil)
        try setRestrictivePermissions(url: url)
    }

    private func writeSecure(data: Data, to url: URL) throws {
        let dir = url.deletingLastPathComponent().path
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: dir, isDirectory: &isDir), isDir.boolValue else { throw ExportError.invalidDestination }
        if FileManager.default.fileExists(atPath: url.path) { throw ExportError.invalidDestination }
        try data.write(to: url, options: .withoutOverwriting)
        try setRestrictivePermissions(url: url)
    }

    private func setRestrictivePermissions(url: URL) throws {
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}

extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
