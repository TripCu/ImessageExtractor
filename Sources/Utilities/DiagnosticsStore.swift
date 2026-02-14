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
    @Published var fullDiskAccessLikelyMissing = false
    @Published var lastResolvedDBPath = ""

    func setLastError(_ category: DiagnosticErrorCategory) { lastError = category }
    func clearLastError() { lastError = nil }
    func updateSchema(_ schema: SchemaProbeResult) { schemaResult = schema }
    func updateCounts(chats: Int?, messages: Int?) {
        if let chats { chatsCount = chats }
        if let messages { messagesCount = messages }
    }

    func redactedDBPath() -> String {
        let path = lastResolvedDBPath.isEmpty ? MessagesDataStore.resolveDBPath(useSynthetic: false) : lastResolvedDBPath
        return path.replacingOccurrences(of: NSHomeDirectory(), with: "/Users/<redacted>")
    }

    func updateFileAccess(path: String, opened: Bool) {
        lastResolvedDBPath = path
        fileExists = FileManager.default.fileExists(atPath: path)
        fileReadable = FileManager.default.isReadableFile(atPath: path)
        sqliteOpenOK = opened
        fullDiskAccessLikelyMissing = fileExists && !fileReadable
    }

    func report(commitHash: String?) -> String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "dev"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        let schemaMissing = schemaResult?.requiredMissing.joined(separator: ", ") ?? "n/a"
        let tables = schemaResult?.tables.sorted().joined(separator: ", ") ?? "n/a"
        let chatColumns = schemaResult?.chatColumns.sorted().joined(separator: ", ") ?? "n/a"
        let messageColumns = schemaResult?.messageColumns.sorted().joined(separator: ", ") ?? "n/a"
        let handleColumns = schemaResult?.handleColumns.sorted().joined(separator: ", ") ?? "n/a"

        return """
        App Version: \(version) (\(build))
        Commit: \(commitHash ?? "unknown")
        macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
        DB Path: \(redactedDBPath())
        DB Exists: \(fileExists)
        DB Readable: \(fileReadable)
        SQLite Open: \(sqliteOpenOK)
        Full Disk Access Likely Missing: \(fullDiskAccessLikelyMissing)
        Last Error: \(lastError?.rawValue ?? "none")
        Chats Count: \(chatsCount)
        Messages Count: \(messagesCount)
        Schema Tables: \(tables)
        Schema chat columns: \(chatColumns)
        Schema message columns: \(messageColumns)
        Schema handle columns: \(handleColumns)
        Schema Missing: \(schemaMissing)
        """
    }

    func copyReport(commitHash: String?) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report(commitHash: commitHash), forType: .string)
    }

    func saveSanitizedDebugLog(to url: URL, commitHash: String?) async throws {
        let logData = await SanitizedLogStore.shared.dump()
        let merged = """
        \(report(commitHash: commitHash))

        --- Sanitized Debug Log ---
        \(logData)
        """
        try merged.data(using: .utf8)?.write(to: url, options: .withoutOverwriting)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
