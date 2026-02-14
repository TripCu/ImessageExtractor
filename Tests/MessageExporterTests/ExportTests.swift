import Foundation
import XCTest
@testable import MessageExporterApp

final class ExportTests: XCTestCase {
    func testJSONExportWritesFile() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: url) }

        let bundle = ExportBundle(
            conversation: .init(id: "c1", sourceRowID: nil, title: "Demo", participantHandles: [], participantDisplayNames: [], lastPreview: nil, lastDate: nil, isGroup: false),
            messages: []
        )

        try Exporter().exportJSON(bundle: bundle, to: url)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }
}
