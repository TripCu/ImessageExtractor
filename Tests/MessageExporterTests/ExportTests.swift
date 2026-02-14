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

    func testTextExportUsesRenderedTextFallback() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".txt")
        defer { try? FileManager.default.removeItem(at: url) }

        let message = MessageItem(
            id: "m1",
            conversationId: "c1",
            date: Date(timeIntervalSince1970: 0),
            sender: "+15551230000",
            isFromMe: false,
            text: nil,
            attributedBodyBase64: Data("fallback body".utf8).base64EncodedString(),
            attachments: []
        )
        let bundle = ExportBundle(
            conversation: .init(id: "c1", sourceRowID: nil, title: "Demo", participantHandles: [], participantDisplayNames: [], lastPreview: nil, lastDate: nil, isGroup: false),
            messages: [message]
        )

        try Exporter().exportText(bundle: bundle, to: url)
        let output = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(output.contains("fallback body"))
    }

    func testDecoderRejectsArchiveNoiseAndKeepsHumanText() {
        let noisy = "streamtyped NSAttributedString NSString Loved â€œAwesome! Thanks Trip! Weâ€™ll put new bed sheets on our bed for you. Just bring whatever else you want for the night! And we will leave a note for you! â€\u{9D} NSDictionary __kIMMessagePartAttributeName"
        let encoded = Data(noisy.utf8).base64EncodedString()
        let decoded = MessageTextDecoder.preferredText(text: nil, attributedBodyBase64: encoded)

        XCTAssertNotNil(decoded)
        XCTAssertTrue(decoded?.contains("Awesome! Thanks Trip!") == true)
        XCTAssertFalse(decoded?.localizedCaseInsensitiveContains("streamtyped") == true)
        XCTAssertFalse(decoded?.localizedCaseInsensitiveContains("NSAttributedString") == true)
    }
}
