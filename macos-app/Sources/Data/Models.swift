import Foundation

struct ConversationSummary: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let participantHandles: [String]
    let lastPreview: String?
    let lastDate: Date?
    let isGroup: Bool
}

struct MessageItem: Identifiable, Hashable, Codable {
    let id: String
    let conversationId: String
    let date: Date
    let sender: String?
    let isFromMe: Bool
    let text: String?
}

struct AttachmentMetadata: Codable, Hashable {
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

struct SchemaProbeResult {
    let chatColumns: Set<String>
    let messageColumns: Set<String>
    let handleColumns: Set<String>
    let requiredMissing: [String]

    var isSupported: Bool { requiredMissing.isEmpty }
}
