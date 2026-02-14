import Testing
@testable import MessageExporterApp

@Test func appleEpochSeconds() {
    let date = AppleDateConverter.convert(raw: 0)
    #expect(date != nil)
    #expect(Int(date!.timeIntervalSince1970) == 978307200)
}
