import Foundation
import OSLog

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
        #endif
    }
}
