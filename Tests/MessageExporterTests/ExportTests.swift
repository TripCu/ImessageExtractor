import Foundation
import Testing
@testable import MessageExporterApp

@Test func jsonExportWritesFile() throws {
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
    let bundle = ExportBundle(conversation: .init(id: "c1", title: "Demo", participantHandles: [], lastPreview: nil, lastDate: nil, isGroup: false), messages: [])
    try Exporter().exportJSON(bundle: bundle, to: tmp)
    #expect(FileManager.default.fileExists(atPath: tmp.path))
}
