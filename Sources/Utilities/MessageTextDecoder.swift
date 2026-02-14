import Foundation

enum MessageTextDecoder {
    private static let bplistHeader = Data("bplist00".utf8)
    private static let disallowedFragments = [
        "bplist00",
        "$objects",
        "$archiver",
        "$top",
        "NSMutableAttributedString",
        "NSAttributedString",
        "NSObject",
        "__kIM"
    ]

    static func preferredText(text: String?, attributedBodyBase64: String?) -> String? {
        if let plain = normalize(text), !plain.isEmpty {
            return plain
        }
        if let derived = decodeAttributedBody(base64: attributedBodyBase64), !derived.isEmpty {
            return derived
        }
        return nil
    }

    private static func decodeAttributedBody(base64: String?) -> String? {
        guard let base64, !base64.isEmpty, let data = Data(base64Encoded: base64) else {
            return nil
        }

        for payload in candidatePayloads(from: data) {
            if let attributed = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSAttributedString.self, from: payload),
               let text = normalize(attributed.string),
               !text.isEmpty {
                return text
            }

            if let archived = decodeArchiveStrings(data: payload) {
                return archived
            }

            if let attributed = decodeAttributedDocument(data: payload),
               let text = normalize(attributed.string),
               !text.isEmpty {
                return text
            }

            if let extracted = extractPrintableSentence(from: payload) {
                return extracted
            }
        }
        return nil
    }

    private static func candidatePayloads(from data: Data) -> [Data] {
        var payloads = [data]
        if let range = data.range(of: bplistHeader), range.lowerBound != data.startIndex {
            payloads.append(data.subdata(in: range.lowerBound..<data.endIndex))
        }
        return payloads
    }

    private static func decodeArchiveStrings(data: Data) -> String? {
        guard let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data) else {
            return nil
        }
        unarchiver.requiresSecureCoding = false
        defer { unarchiver.finishDecoding() }
        guard let root = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) else {
            return nil
        }

        var candidates: [String] = []
        collectStrings(from: root, depth: 0, into: &candidates)
        return bestCandidate(in: candidates)
    }

    private static func collectStrings(from value: Any, depth: Int, into output: inout [String]) {
        guard depth < 10 else { return }

        if let attributed = value as? NSAttributedString {
            if let cleaned = cleanedCandidate(attributed.string) {
                output.append(cleaned)
            }
            return
        }
        if let text = value as? String {
            if let cleaned = cleanedCandidate(text) {
                output.append(cleaned)
            }
            return
        }
        if let array = value as? [Any] {
            for item in array {
                collectStrings(from: item, depth: depth + 1, into: &output)
            }
            return
        }
        if let dict = value as? [AnyHashable: Any] {
            for (key, nestedValue) in dict {
                collectStrings(from: key, depth: depth + 1, into: &output)
                collectStrings(from: nestedValue, depth: depth + 1, into: &output)
            }
            return
        }
        if let nsDict = value as? NSDictionary {
            for entry in nsDict {
                collectStrings(from: entry.key, depth: depth + 1, into: &output)
                collectStrings(from: entry.value, depth: depth + 1, into: &output)
            }
        }
    }

    private static func extractPrintableSentence(from data: Data) -> String? {
        let decoded = String(decoding: data, as: UTF8.self)
        let pattern = #"[A-Za-z0-9][A-Za-z0-9 ,.'!?;:()\-]{7,}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let nsRange = NSRange(decoded.startIndex..<decoded.endIndex, in: decoded)
        let matches = regex.matches(in: decoded, options: [], range: nsRange)
        var candidates: [String] = []
        for match in matches {
            guard let range = Range(match.range, in: decoded) else { continue }
            let value = String(decoded[range])
            if let cleaned = cleanedCandidate(value) {
                candidates.append(cleaned)
            }
        }
        return bestCandidate(in: candidates)
    }

    private static func bestCandidate(in rawCandidates: [String]) -> String? {
        let unique = Array(Set(rawCandidates))
        let best = unique.max { lhs, rhs in
            score(candidate: lhs) < score(candidate: rhs)
        }
        return best
    }

    private static func score(candidate: String) -> Int {
        let words = candidate.split(whereSeparator: \.isWhitespace).count
        let letters = candidate.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
        let punctuationBonus = candidate.contains(".") || candidate.contains("!") || candidate.contains("?") ? 20 : 0
        return (words * 12) + letters + punctuationBonus
    }

    private static func cleanedCandidate(_ text: String) -> String? {
        guard var value = normalize(text) else { return nil }
        value = repairCommonMojibake(value)

        let lowered = value.lowercased()
        if disallowedFragments.contains(where: { lowered.contains($0.lowercased()) }) {
            return nil
        }

        let letters = value.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
        let digits = value.unicodeScalars.filter { CharacterSet.decimalDigits.contains($0) }.count
        if letters + digits < 4 {
            return nil
        }
        let words = value.split(whereSeparator: \.isWhitespace).count
        if words < 2 {
            return nil
        }

        let controls = value.unicodeScalars.filter { CharacterSet.controlCharacters.contains($0) }.count
        if controls > 0 {
            return nil
        }
        return value
    }

    private static func repairCommonMojibake(_ value: String) -> String {
        value
            .replacingOccurrences(of: "â€™", with: "’")
            .replacingOccurrences(of: "â€œ", with: "“")
            .replacingOccurrences(of: "â€\u{9D}", with: "”")
            .replacingOccurrences(of: "â€“", with: "–")
            .replacingOccurrences(of: "â€”", with: "—")
    }

    private static func decodeAttributedDocument(data: Data) -> NSAttributedString? {
        let formats: [NSAttributedString.DocumentType] = [.rtfd, .rtf, .html, .plain]
        for format in formats {
            if let value = try? NSAttributedString(
                data: data,
                options: [.documentType: format],
                documentAttributes: nil
            ) {
                return value
            }
        }
        return nil
    }

    private static func normalize(_ value: String?) -> String? {
        guard let value else { return nil }
        let noObject = value.replacingOccurrences(of: "\u{FFFC}", with: "")
        let noNul = noObject.replacingOccurrences(of: "\0", with: "")
        let squashed = noNul.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        let trimmed = squashed.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
