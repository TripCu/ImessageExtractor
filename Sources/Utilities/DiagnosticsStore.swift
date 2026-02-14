import AppKit
import Foundation

enum DiagnosticErrorCategory: String {
    case permission
    case missingFile
    case schemaMismatch
    case unknown
}

@MainActor
final class DiagnosticsStore: ObservableObject {
    @Published var lastError: DiagnosticErrorCategory?
    @Published var schemaResult: SchemaProbeResult?
    @Published var chatsCount: Int = 0
    @Published var messagesCount: Int = 0
    @Published var fileExists = false
    @Published var fileReadable = false
    @Published var sqliteOpenOK = false

    func setLastError(_ category: DiagnosticErrorCategory) { lastError = category }
    func updateSchema(_ schema: SchemaProbeResult) { schemaResult = schema }
    func updateCounts(chats: Int?, messages: Int?) {
        if let chats { chatsCount = chats }
        if let messages { messagesCount = messages }
    }

    func redactedDBPath() -> String {
        MessagesDataStore.resolveDBPath(useSynthetic: false).replacingOccurrences(of: NSHomeDirectory(), with: "/Users/<redacted>")
    }

    func updateFileAccess(path: String, opened: Bool) {
        fileExists = FileManager.default.fileExists(atPath: path)
        fileReadable = FileManager.default.isReadableFile(atPath: path)
        sqliteOpenOK = opened
    }

    func report(commitHash: String?) -> String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "dev"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        let schemaMissing = schemaResult?.requiredMissing.joined(separator: ", ") ?? "n/a"

        return """
        App Version: \(version) (\(build))
        Commit: \(commitHash ?? "unknown")
        macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
        DB Path: \(redactedDBPath())
        DB Exists: \(fileExists)
        DB Readable: \(fileReadable)
        SQLite Open: \(sqliteOpenOK)
        Last Error: \(lastError?.rawValue ?? "none")
        Chats Count: \(chatsCount)
        Messages Count: \(messagesCount)
        Schema Missing: \(schemaMissing)
        """
    }

    func copyReport(commitHash: String?) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report(commitHash: commitHash), forType: .string)
    }
}
