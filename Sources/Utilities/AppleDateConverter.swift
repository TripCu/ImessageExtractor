import Foundation

enum AppleDateConverter {
    private static let appleEpochOffset: TimeInterval = 978_307_200

    static func convert(raw: Int64?) -> Date? {
        guard let raw else { return nil }
        let absVal = abs(raw)
        let seconds: TimeInterval
        if absVal > 9_000_000_000_000_000 {
            seconds = TimeInterval(raw) / 1_000_000_000
        } else if absVal > 9_000_000_000_000 {
            seconds = TimeInterval(raw) / 1_000_000
        } else if absVal > 9_000_000_000 {
            seconds = TimeInterval(raw) / 1_000
        } else {
            seconds = TimeInterval(raw)
        }
        return Date(timeIntervalSince1970: seconds + appleEpochOffset)
    }
}
