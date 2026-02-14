import Foundation

enum MessageTextDecoder {
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

        if let attributed = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSAttributedString.self, from: data),
           let text = normalize(attributed.string),
           !text.isEmpty {
            return text
        }

        if let attributed = decodeAttributedDocument(data: data),
           let text = normalize(attributed.string),
           !text.isEmpty {
            return text
        }

        if let utf8 = normalize(String(data: data, encoding: .utf8)), !utf8.isEmpty {
            return utf8
        }
        if let utf16 = normalize(String(data: data, encoding: .utf16LittleEndian)), !utf16.isEmpty {
            return utf16
        }
        return nil
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
        let trimmed = noNul.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
