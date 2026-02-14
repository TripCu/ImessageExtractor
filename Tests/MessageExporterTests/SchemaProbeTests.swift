import Foundation
import XCTest
@testable import MessageExporterApp

final class SchemaProbeTests: XCTestCase {
    func testProbeSupportedSchemaFixture() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let root = testFile.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let path = root.appendingPathComponent("Resources/synthetic-chat.db").path
        let db = try SQLiteReadOnly(path: path)
        let probe = try SchemaProbe.probe(db: db)
        XCTAssertTrue(probe.isSupported)
        XCTAssertTrue(probe.chatColumns.contains("guid"))
        XCTAssertTrue(probe.messageColumns.contains("date"))
    }
}
