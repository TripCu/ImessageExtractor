import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var setupCompleted: Bool
    @Published var showDiagnostics = false
    @Published var privacyModeEnabled = true
    @Published var resolveContactNames = false
    @Published var selectedConversationID: String?

    let defaults = UserDefaults.standard
    var dataStore: MessagesDataStore
    let contactResolver = ContactResolver()
    let diagnosticsStore = DiagnosticsStore()

    var selectedConversation: ConversationSummary? {
        guard let id = selectedConversationID else { return nil }
        return dataStore.conversations.first(where: { $0.id == id })
    }

    init() {
        setupCompleted = defaults.bool(forKey: "setupCompleted")
        resolveContactNames = defaults.bool(forKey: "resolveContactNames")
        dataStore = MessagesDataStore(diagnostics: diagnosticsStore)
        AppLogger.info("Startup", "App state initialized")
    }

    func markSetupCompleted() {
        setupCompleted = true
        defaults.set(true, forKey: "setupCompleted")
    }

    func setResolveContactNames(_ enabled: Bool) {
        resolveContactNames = enabled
        defaults.set(enabled, forKey: "resolveContactNames")
    }

    func clearInvalidSelectionIfNeeded() {
        guard let id = selectedConversationID else { return }
        if !dataStore.conversations.contains(where: { $0.id == id }) {
            selectedConversationID = nil
        }
    }
}
