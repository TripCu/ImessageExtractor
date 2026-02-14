import Foundation
import OSLog

actor SanitizedLogStore {
    static let shared = SanitizedLogStore()
    private var lines: [String] = []
    private let maxLines = 2_000

    func append(category: String, level: String, message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "\(timestamp) [\(level)] [\(category)] \(redact(message))"
        lines.append(line)
        if lines.count > maxLines {
            lines.removeFirst(lines.count - maxLines)
        }
    }

    func dump() -> String {
        lines.joined(separator: "\n")
    }

    private func redact(_ text: String) -> String {
        text.replacingOccurrences(of: NSHomeDirectory(), with: "/Users/<redacted>")
    }
}

struct AppLogger {
    static let startup = Logger(subsystem: "org.example.MessageExporter", category: "Startup")
    static let db = Logger(subsystem: "org.example.MessageExporter", category: "DB")
    static let schema = Logger(subsystem: "org.example.MessageExporter", category: "Schema")
    static let export = Logger(subsystem: "org.example.MessageExporter", category: "Export")
    static let ui = Logger(subsystem: "org.example.MessageExporter", category: "UI")
    static let contacts = Logger(subsystem: "org.example.MessageExporter", category: "Contacts")

    static func logDBPath(_ path: String) {
        #if DEBUG
        db.info("DB path: \(path, privacy: .private)")
        Task { await SanitizedLogStore.shared.append(category: "DB", level: "INFO", message: "DB path configured") }
        #endif
    }

    static func debug(_ category: String, _ message: String) {
        #if DEBUG
        emit(category, message, level: "DEBUG")
        #endif
    }

    static func info(_ category: String, _ message: String) {
        #if DEBUG
        emit(category, message, level: "INFO")
        #endif
    }

    static func error(_ category: String, _ message: String) {
        emit(category, message, level: "ERROR")
    }

    private static func emit(_ category: String, _ message: String, level: String) {
        let logger = loggerForCategory(category)
        switch level {
        case "DEBUG":
            #if DEBUG
            logger.debug("\(message, privacy: .private)")
            #endif
        case "ERROR":
            logger.error("\(message, privacy: .private)")
        default:
            logger.info("\(message, privacy: .private)")
        }
        #if DEBUG
        Task { await SanitizedLogStore.shared.append(category: category, level: level, message: message) }
        #endif
    }

    private static func loggerForCategory(_ category: String) -> Logger {
        switch category {
        case "Startup": return startup
        case "DB": return db
        case "Schema": return schema
        case "Export": return export
        case "UI": return ui
        case "Contacts": return contacts
        default: return Logger(subsystem: "org.example.MessageExporter", category: category)
        }
    }
}
