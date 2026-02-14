import Foundation
import Testing
@testable import MessageExporterApp

@Test func probeSupportedSchema() throws {
    let testFile = URL(fileURLWithPath: #filePath)
    let root = testFile.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let path = root.appendingPathComponent("Resources/synthetic-chat.db").path
    let db = try SQLiteReadOnly(path: path)
    let probe = try SchemaProbe.probe(db: db)
    #expect(probe.isSupported)
}
