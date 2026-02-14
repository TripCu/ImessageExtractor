import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var setupCompleted: Bool
    @Published var showDiagnostics = false
    @Published var privacyModeEnabled = true
    @Published var selectedConversation: ConversationSummary?

    let defaults = UserDefaults.standard
    var dataStore: MessagesDataStore
    let contactResolver = ContactResolver()
    let diagnosticsStore = DiagnosticsStore()

    init() {
        setupCompleted = defaults.bool(forKey: "setupCompleted")
        dataStore = MessagesDataStore(diagnostics: diagnosticsStore)
    }

    func markSetupCompleted() {
        setupCompleted = true
        defaults.set(true, forKey: "setupCompleted")
    }
}
