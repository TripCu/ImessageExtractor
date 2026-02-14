import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

struct ExportBundle: Encodable {
    let conversation: ConversationSummary
    let messages: [MessageItem]
}

enum ExportError: Error, LocalizedError {
    case invalidDestination
    case writeFailed
    case encryptionPassphraseMissing

    var errorDescription: String? {
        switch self {
        case .invalidDestination: return "Invalid destination or file already exists."
        case .writeFailed: return "Failed to write export file."
        case .encryptionPassphraseMissing: return "Passphrase is required for encrypted export."
        }
    }
}

final class Exporter {
    func exportText(bundle: ExportBundle, to url: URL) throws {
        let lines = bundle.messages.map { msg in
            let ts = ISO8601DateFormatter().string(from: msg.date)
            let sender = msg.isFromMe ? "Me" : (msg.sender ?? "Unknown")
            return "[\(ts)] \(sender): \(msg.renderedText)"
        }
        try writeSecure(data: lines.joined(separator: "\n").data(using: .utf8) ?? Data(), to: url)
    }

    func exportJSON(bundle: ExportBundle, to url: URL) throws {
        let data = try JSONEncoder.pretty.encode(bundle)
        try writeSecure(data: data, to: url)
    }

    func exportEncrypted(bundle: ExportBundle, passphrase: String, to url: URL) throws {
        guard !passphrase.isEmpty else { throw ExportError.encryptionPassphraseMissing }
        let data = try JSONEncoder.pretty.encode(bundle)
        let encrypted = try EncryptedPackage.encrypt(plaintext: data, passphrase: passphrase)
        try writeSecure(data: encrypted, to: url)
    }

    func exportSQLite(bundle: ExportBundle, to url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) { throw ExportError.invalidDestination }
        var db: OpaquePointer?
        guard sqlite3_open(url.path, &db) == SQLITE_OK, let db else { throw ExportError.writeFailed }
        defer { sqlite3_close(db) }

        let schemaSQL = """
        PRAGMA journal_mode=WAL;
        CREATE TABLE conversation(
          id TEXT PRIMARY KEY,
          title TEXT,
          is_group INTEGER,
          exported_at REAL
        );
        CREATE TABLE participant(
          conversation_id TEXT,
          handle TEXT,
          display_name TEXT
        );
        CREATE TABLE message(
          id TEXT PRIMARY KEY,
          conversation_id TEXT,
          sender TEXT,
          date REAL,
          text TEXT,
          attributed_body_base64 TEXT,
          is_from_me INTEGER
        );
        CREATE TABLE attachment(
          message_id TEXT,
          filename TEXT,
          mime_type TEXT,
          transfer_name TEXT
        );
        """

        guard sqlite3_exec(db, schemaSQL, nil, nil, nil) == SQLITE_OK else {
            throw ExportError.writeFailed
        }

        guard sqlite3_exec(db, "BEGIN;", nil, nil, nil) == SQLITE_OK else {
            throw ExportError.writeFailed
        }

        do {
            try insertConversation(bundle.conversation, db: db)
            for (index, handle) in bundle.conversation.participantHandles.enumerated() {
                let display = index < bundle.conversation.participantDisplayNames.count ? bundle.conversation.participantDisplayNames[index] : handle
                try insertParticipant(conversationID: bundle.conversation.id, handle: handle, displayName: display, db: db)
            }
            for message in bundle.messages {
                try insertMessage(message, conversationID: bundle.conversation.id, db: db)
                for attachment in message.attachments {
                    try insertAttachment(attachment, messageID: message.id, db: db)
                }
            }
            guard sqlite3_exec(db, "COMMIT;", nil, nil, nil) == SQLITE_OK else {
                throw ExportError.writeFailed
            }
        } catch {
            _ = sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            throw error
        }

        try setRestrictivePermissions(url: url)
    }

    private func insertConversation(_ conversation: ConversationSummary, db: OpaquePointer) throws {
        let sql = "INSERT INTO conversation(id,title,is_group,exported_at) VALUES(?,?,?,?);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw ExportError.writeFailed
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, conversation.id, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, conversation.title, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 3, conversation.isGroup ? 1 : 0)
        sqlite3_bind_double(stmt, 4, Date().timeIntervalSince1970)

        guard sqlite3_step(stmt) == SQLITE_DONE else { throw ExportError.writeFailed }
    }

    private func insertParticipant(conversationID: String, handle: String, displayName: String, db: OpaquePointer) throws {
        let sql = "INSERT INTO participant(conversation_id,handle,display_name) VALUES(?,?,?);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw ExportError.writeFailed
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, conversationID, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, handle, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, displayName, -1, SQLITE_TRANSIENT)

        guard sqlite3_step(stmt) == SQLITE_DONE else { throw ExportError.writeFailed }
    }

    private func insertMessage(_ message: MessageItem, conversationID: String, db: OpaquePointer) throws {
        let sql = "INSERT INTO message(id,conversation_id,sender,date,text,attributed_body_base64,is_from_me) VALUES(?,?,?,?,?,?,?);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw ExportError.writeFailed
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, message.id, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, conversationID, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, message.sender ?? "", -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(stmt, 4, message.date.timeIntervalSince1970)
        sqlite3_bind_text(stmt, 5, message.renderedText, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 6, message.attributedBodyBase64 ?? "", -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 7, message.isFromMe ? 1 : 0)

        guard sqlite3_step(stmt) == SQLITE_DONE else { throw ExportError.writeFailed }
    }

    private func insertAttachment(_ attachment: AttachmentMetadata, messageID: String, db: OpaquePointer) throws {
        let sql = "INSERT INTO attachment(message_id,filename,mime_type,transfer_name) VALUES(?,?,?,?);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw ExportError.writeFailed
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, messageID, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, attachment.filename ?? "", -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, attachment.mimeType ?? "", -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 4, attachment.transferName ?? "", -1, SQLITE_TRANSIENT)

        guard sqlite3_step(stmt) == SQLITE_DONE else { throw ExportError.writeFailed }
    }

    private func writeSecure(data: Data, to url: URL) throws {
        let dir = url.deletingLastPathComponent().path
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: dir, isDirectory: &isDir), isDir.boolValue else {
            throw ExportError.invalidDestination
        }
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
