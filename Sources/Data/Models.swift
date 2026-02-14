import Foundation

struct ConversationSummary: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let sourceRowID: Int64?
    let title: String
    let participantHandles: [String]
    let participantDisplayNames: [String]
    let lastPreview: String?
    let lastDate: Date?
    let isGroup: Bool

    var selectionKey: String {
        if let sourceRowID {
            return "rowid:\(sourceRowID)"
        }
        return "id:\(id)"
    }
}

struct MessageItem: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let conversationId: String
    let date: Date
    let sender: String?
    let isFromMe: Bool
    let text: String?
    let attributedBodyBase64: String?
    let attachments: [AttachmentMetadata]

    var renderedText: String {
        if let value = MessageTextDecoder.preferredText(text: text, attributedBodyBase64: attributedBodyBase64),
           !value.isEmpty {
            return value
        }
        if !attachments.isEmpty {
            return "[Attachment]"
        }
        return "[No text body]"
    }
}

struct AttachmentMetadata: Codable, Hashable, Sendable {
    let filename: String?
    let mimeType: String?
    let transferName: String?
}

enum ExportFormat: String, CaseIterable, Identifiable {
    case text
    case json
    case sqlite
    case encrypted

    var id: String { rawValue }
}

struct SchemaProbeResult: Sendable {
    let tables: Set<String>
    let chatColumns: Set<String>
    let messageColumns: Set<String>
    let messageSummaryInfoColumns: Set<String>
    let handleColumns: Set<String>
    let chatHandleJoinColumns: Set<String>
    let chatMessageJoinColumns: Set<String>
    let messageAttachmentJoinColumns: Set<String>
    let attachmentColumns: Set<String>
    let requiredMissing: [String]

    var isSupported: Bool { requiredMissing.isEmpty }
}
