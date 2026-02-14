import XCTest
@testable import MessageExporterApp

final class DateConverterTests: XCTestCase {
    func testAppleEpochSeconds() {
        let date = AppleDateConverter.convert(raw: 0)
        XCTAssertNotNil(date)
        XCTAssertEqual(Int(date?.timeIntervalSince1970 ?? 0), 978_307_200)
    }

    func testAppleEpochMicros() {
        let date = AppleDateConverter.convert(raw: 1_000_000)
        XCTAssertNotNil(date)
        XCTAssertEqual(Int(date?.timeIntervalSince1970 ?? 0), 978_307_201)
    }
}
